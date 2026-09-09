require "net/http"
require "json"


class AzureAPIMError < StandardError
  attr_reader :code

  def initialize(msg, code=nil)
    @code = code
    super(msg)
  end
end

class AzureAPIM
  def initialize(service_name:, subscription_id:, resource_group_name:)
    @base_url = "https://management.azure.com/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.ApiManagement/service/#{service_name}"
  end

  def self.instance
    config = {
      # Use SiteSetting.get to raise an error if the setting isn't set
      service_name: SiteSetting.get('discourse_apim_azure_service_name'),
      subscription_id: SiteSetting.get('discourse_apim_azure_subscription_id'),
      resource_group_name: SiteSetting.get('discourse_apim_azure_resource_group_name'),
    }

    @@instance ||= AzureAPIM.new(**config)
  end

  def self.additional_reporting_instance
    config = {
      subscription_id: SiteSetting.get('discourse_apim_azure_subscription_id'),
      resource_group_name: SiteSetting.get('discourse_apim_azure_resource_group_name'),
      service_name: SiteSetting.discourse_apim_azure_additional_reporting_service_name,
    }

    if config[:service_name].present?
      @@additional_reporting_instance ||= AzureAPIM.new(**config)
    end
  end

  # The direct APIM management API (and its shared access signature keys) was retired in
  # March 2025, so we authenticate against the Azure Resource Manager API instead, using an
  # access token from the VM's managed identity:
  # https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#get-a-token-using-http
  #
  # Both the instance metadata service and the CLI cache the token they return until shortly
  # before it expires, so it's fine to call this on every request rather than caching it
  # ourselves.
  def get_access_token
    return access_token_from_cli if @use_cli

    token = begin
      access_token_from_managed_identity
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout
      # There's no metadata service to talk to outside of an Azure VM (eg. local dev).
      nil
    end

    return token if token

    # Either there's no metadata service, or it has no identity to give us a token for.
    # Fall back to the Azure CLI, and remember to do so next time so we don't pay the
    # metadata service's connection timeout on every request.
    @use_cli = true
    access_token_from_cli
  end

  # Returns nil rather than raising if this doesn't look like a VM with a managed identity,
  # so the caller can fall back to the CLI.
  def access_token_from_managed_identity
    url = UrlHelper.encode_and_parse("http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/")

    request = Net::HTTP::Get.new(url)
    request['Metadata'] = 'true'

    response = Net::HTTP.start(url.host, url.port, :open_timeout => 1, :read_timeout => 5) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)['access_token'].presence
  rescue JSON::ParserError
    nil
  end

  def access_token_from_cli
    # Not running on a VM with a managed identity - fall back to the Azure CLI, eg. for local dev
    output = begin
      `az account get-access-token --resource https://management.azure.com/ 2>/dev/null`
    rescue Errno::ENOENT
      ""
    end

    token = begin
      JSON.parse(output)['accessToken'].presence
    rescue JSON::ParserError
      nil
    end

    if token.nil?
      raise AzureAPIMError.new(
        "Could not get an Azure access token. On an Azure VM this comes from the managed " \
        "identity, which needs an RBAC role assignment (eg. API Management Service " \
        "Contributor) on the resource group. Elsewhere (eg. local development) install the " \
        "Azure CLI and run `az login`."
      )
    end

    token
  end

  def request(method, endpoint, params: {}, body: nil)
    params['api-version'] = '2022-08-01'
    param_string = params.map { |v| v.join("=") }.join("&")

    url = UrlHelper.encode_and_parse("#{@base_url}/#{endpoint}?#{param_string}")

    request = method.new(url)
    request['Authorization'] = "Bearer #{self.get_access_token}"

    if body
      request['Content-Type'] = "application/json"
      request.body = body
    end

    response = Net::HTTP.start(url.host, url.port, :use_ssl => true) do |http|
      http.request(request)
    end

    json = JSON.parse(response.body)

    if json['nextLink']
      raise AzureAPIMError.new "DEVELOPER ERROR: need to handle nextLink for #{endpoint}"
    end

    if json['error']
      raise AzureAPIMError.new json['error']['message'] || 'Unknown AzureAPIM error', json['error']['code']
    else
      json['value'] || json
    end
  end

  def list_products
    request(Net::HTTP::Get, "products")
  end

  def list_subscriptions
    request(Net::HTTP::Get, "subscriptions", params: {
      '$top': 1000
    })
  end

  def list_users
    request(Net::HTTP::Get, "users", params: {
      '$top': 1000
    })
  end

  def list_subscriptions_for_user(user:)
    request(Net::HTTP::Get, "users/#{user}/subscriptions")
  end

  def create_or_update_user(user:, email:, first_name:, last_name:)
    body = {
      "properties": {
        "email": email,
        "firstName": first_name,
        "lastName": last_name
      }
    }

    request(Net::HTTP::Put, "users/#{user}", body: JSON.generate(body))
  end

  def create_subscription_to_product(user:, product:, email:)
    sid = "#{product}-#{user}"

    body = {
      "properties": {
        "displayName": "#{product} #{email}",
        "scope": "/products/#{product}",
        "ownerId": "/users/#{user}"
      }
    }

    request(Net::HTTP::Put, "subscriptions/#{sid}", body: JSON.generate(body))

    sid
  end

  def show_api_keys(sid:)
    request(Net::HTTP::Post, "subscriptions/#{sid}/listSecrets")
  end

  def get_usage(start_time:, end_time:)
    fmt = "%Y-%m-%dT%H:%M:%S"

    start_time_clause = "timestamp ge datetime'#{start_time.strftime(fmt)}'"

    end_time_clause = ""
    if end_time
      end_time_clause = " and timestamp le datetime'#{end_time.strftime(fmt)}'"
    end

    request(Net::HTTP::Get, "reports/bySubscription", params: {
      "$filter": "#{start_time_clause}#{end_time_clause}"
    })
  end
end
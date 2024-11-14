require "base64"
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
  def initialize(service_name:, subscription_id:, resource_group_name:, management_key:)
    @management_key = management_key
    @base_url = "https://management.azure.com/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.ApiManagement/service/#{service_name}"
  end

  def self.instance
    config = {
      # Use SiteSetting.get to raise an error if the setting isn't set
      service_name: SiteSetting.get('discourse_apim_azure_service_name'),
      subscription_id: SiteSetting.get('discourse_apim_azure_subscription_id'),
      resource_group_name: SiteSetting.get('discourse_apim_azure_resource_group_name'),
      management_key: SiteSetting.get('discourse_apim_azure_management_key'),
    }

    @@instance ||= AzureAPIM.new(**config)
  end

  def self.additional_reporting_instance
    config = {
      subscription_id: SiteSetting.get('discourse_apim_azure_subscription_id'),
      resource_group_name: SiteSetting.get('discourse_apim_azure_resource_group_name'),
      service_name: SiteSetting.discourse_apim_azure_additional_reporting_service_name,
      management_key: SiteSetting.discourse_apim_azure_additional_reporting_management_key
    }

    if config[:service_name] and config[:management_key]
      @@additional_reporting_instance ||= AzureAPIM.new(**config)
    end
  end

  def access_token_from_cli
    # Not running in VM in Azure, use CLI
    response = `az account get-access-token`

    json = JSON.parse(response)

    return json['accessToken']
  end

  def access_token_from_vm_metadata_api
    # https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#get-a-token-using-http
    url = UrlHelper.encode_and_parse("http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/")

    request = Net::HTTP::Get.new(url)
    request['Metadata'] = 'true'

    response = Net::HTTP.start(url.host, url.port, :read_timeout => 500) do |http|
      http.request(request)
    end

    json = JSON.parse(response)

    return json['access_token']
  end

  def get_access_token
    # Both the HTTP API and CLI command cache their return value so it's fine to call them every time
    # We remember which one we're supposed to use though to avoid waiting the connect timeout in local dev every time

    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!! use_cli: #{@use_cli}   !!"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    if @use_cli
      return self.access_token_from_cli
    else
      begin
        self.access_token_from_vm_metadata_api
      rescue Errno::EHOSTUNREACH
        @use_cli = true
        return self.access_token_from_cli
      end
    end

    # # https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#get-a-token-using-http
    # url = UrlHelper.encode_and_parse("http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/")

    # request = Net::HTTP::Get.new(url)
    # request['Metadata'] = 'true'

    # begin
    #   response = Net::HTTP.start(url.host, url.port, :read_timeout => 500) do |http|
    #     http.request(request)
    #   end

    #   json = JSON.parse(response)

    #   return json['access_token']

    # rescue Errno::EHOSTUNREACH
    #   @use_cli = true

      
    # end
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
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
    @base_url = "https://#{service_name}.management.azure-api.net/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.ApiManagement/service/#{service_name}"
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

  def generate_token
    identifier = "integration"
    
    expiry = (Time.now + 1.hour).strftime("%Y-%m-%dT%H:%M:%S.0000000Z")
    string_to_sign = "#{identifier}\n#{expiry}"
    
    digest = OpenSSL::HMAC.digest("SHA512", @management_key, string_to_sign)
    sn = Base64.strict_encode64(digest)
    
    "uid=integration&ex=#{expiry}&sn=#{sn}"
  end

  def request(method, endpoint, params: {}, body: nil)
    params['api-version'] = '2022-08-01'
    param_string = params.map { |v| v.join("=") }.join("&")

    url = UrlHelper.encode_and_parse("#{@base_url}/#{endpoint}?#{param_string}")

    request = method.new(url)
    request['Authorization'] = "SharedAccessSignature #{self.generate_token}"

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
    self.request(Net::HTTP::Get, "products")
  end

  def list_subscriptions
    self.request(Net::HTTP::Get, "subscriptions", params: {
      '$top': 1000
    })
  end

  def list_users
    self.request(Net::HTTP::Get, "users", params: {
      '$top': 1000
    })
  end

  def list_subscriptions_for_user(user:)
    self.request(Net::HTTP::Get, "users/#{user}/subscriptions")
  end

  def create_or_update_user(user:, email:, first_name:, last_name:)
    body = {
      "properties": {
        "email": email,
        "firstName": first_name,
        "lastName": last_name
      }
    }

    self.request(Net::HTTP::Put, "users/#{user}", body: JSON.generate(body))
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

    self.request(Net::HTTP::Put, "subscriptions/#{sid}", body: JSON.generate(body))
  end

  def show_api_keys(user:, product:)
    sid = "#{product}-#{user}"

    self.request(Net::HTTP::Post, "subscriptions/#{sid}/listSecrets")
  end

  def get_usage(start_time:, end_time:)
    fmt = "%Y-%m-%dT%H:%M:%S"

    start_time_clause = "timestamp ge datetime'#{start_time.strftime(fmt)}'"

    end_time_clause = ""
    if end_time
      end_time_clause = " and timestamp le datetime'#{end_time.strftime(fmt)}'"
    end

    self.request(Net::HTTP::Get, "reports/bySubscription", params: {
      "$filter": "#{start_time_clause}#{end_time_clause}"
    })
  end
end
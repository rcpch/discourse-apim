require "base64"
require "net/http"
require "json"

# @@apim_base = 'https://rcpch-apim.management.azure-api.net/subscriptions/99e313f5-79fe-4480-b867-8daf2800cf22/resourceGroups/RCPCH-Dev-API-Growth/providers/Microsoft.ApiManagement/service/rcpch-apim'

class AzureAPIMError < StandardError
  attr_reader :code

  def initialize(msg, code=nil)
    @code = code
    super(msg)
  end
end

class AzureAPIM
  def self.base_url
    service_name = SiteSetting.discourse_apim_azure_service_name
    subscription_id = SiteSetting.discourse_apim_azure_subscription_id
    resource_group_name = SiteSetting.discourse_apim_azure_resource_group_name

    "https://#{service_name}.management.azure-api.net/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.ApiManagement/service/#{service_name}"
  end

  def self.generate_token
    identifier = "integration"
    key = SiteSetting.discourse_apim_azure_management_key
    
    expiry = (Time.now + (60 * 60)).strftime("%Y-%m-%dT%H:%M:%S.0000000Z")
    string_to_sign = "#{identifier}\n#{expiry}"
    
    digest = OpenSSL::HMAC.digest("SHA512", key, string_to_sign)
    sn = Base64.strict_encode64(digest)
    
    "uid=integration&ex=#{expiry}&sn=#{sn}"
  end

  def self.request(method, endpoint, params = {}, body = nil)
    params['api-version'] = '2022-08-01'
    param_string = params.map { |v| v.join("=") }.join("&")

    url = UrlHelper.encode_and_parse("#{AzureAPIM.base_url}/#{endpoint}?#{param_string}")

    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!! #{url} #{param_string}"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    request = method.new(url)
    request['Authorization'] = "SharedAccessSignature #{AzureAPIM.generate_token}"

    if body
      request['Content-Type'] = "application/json"
      request.body = body

      puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      puts "!!!!!!!!!!! #{body}"
      puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    end

    response = Net::HTTP.start(url.host, url.port, :use_ssl => true) do |http|
      http.request(request)
    end

    json = JSON.parse(response.body)

    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!! #{json}"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    if json['error']
      raise AzureAPIMError.new json['error']['message'] || 'Unknown AzureAPIM error', json['error']['code']
    else
      json['value'] || json
    end
  end

  def self.list_products
    AzureAPIM.request(Net::HTTP::Get, "products")
  end

  def self.list_subscriptions(user:)
    AzureAPIM.request(Net::HTTP::Get, "users/#{user}/subscriptions")
  end

  def self.create_or_update_user(user:, email:, first_name:, last_name:)
    body = {
      "properties": {
        "email": email,
        "firstName": first_name,
        "lastName": last_name
      }
    }

    AzureAPIM.request(Net::HTTP::Put, "users/#{user}", JSON.generate(body))
  end

  def self.create_subscription_to_product(user:, product:, email:)
    sid = "#{product}-#{user}"

    body = {
      "properties": {
        "displayName": "#{product} #{email}",
        "scope": "/products/#{product}",
        "ownerId": "/users/#{user}"
      }
    }

    AzureAPIM.request(Net::HTTP::Put, "subscriptions/#{sid}", JSON.generate(body))
  end

  def self.show_api_keys(user:, product:)
    sid = "#{product}-#{user}"

    AzureAPIM.request(Net::HTTP::Post, "subscriptions/#{sid}/listSecrets")
  end

  def self.get_usage(start_time:, end_time:)
    fmt = "%Y-%m-%dT%H:%M:%S"

    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!! #{start_time} #{end_time}"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    start_time_clause = "timestamp ge datetime'#{start_time.strftime(fmt)}'"

    end_time_clause = ""
    if end_time
      end_time_clause = " and timestamp le '#{end_time.strftime(fmt)}'"
    end

    AzureAPIM.request(Net::HTTP::Get, "reports/bySubscription", params = {
      "$filter": "#{start_time_clause}#{end_time_clause}"
    })
  end
end
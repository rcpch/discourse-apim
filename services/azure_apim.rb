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

  def self.primary_instance
    @@primary_instance ||= AzureAPIM.new(
      service_name: SiteSetting.discourse_apim_azure_service_name,
      subscription_id: SiteSetting.discourse_apim_azure_subscription_id,
      resource_group_name: SiteSetting.discourse_apim_azure_resource_group_name,
      management_key: SiteSetting.discourse_apim_azure_management_key
    )

    @@primary_instance
  end

  # def self.base_url
  #   service_name = SiteSetting.discourse_apim_azure_service_name
  #   subscription_id = SiteSetting.discourse_apim_azure_subscription_id
  #   resource_group_name = SiteSetting.discourse_apim_azure_resource_group_name

  #   "https://#{service_name}.management.azure-api.net/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.ApiManagement/service/#{service_name}"
  # end

  def generate_token
    identifier = "integration"
    
    expiry = (Time.now + (60 * 60)).strftime("%Y-%m-%dT%H:%M:%S.0000000Z")
    string_to_sign = "#{identifier}\n#{expiry}"
    
    digest = OpenSSL::HMAC.digest("SHA512", @management_key, string_to_sign)
    sn = Base64.strict_encode64(digest)
    
    "uid=integration&ex=#{expiry}&sn=#{sn}"
  end

  def request(method, endpoint, params: {}, body: nil)
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!! params=#{params} body=#{body}"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    params['api-version'] = '2022-08-01'
    param_string = params.map { |v| v.join("=") }.join("&")

    url = UrlHelper.encode_and_parse("#{@base_url}/#{endpoint}?#{param_string}")

    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!! #{url} #{param_string}"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    request = method.new(url)
    request['Authorization'] = "SharedAccessSignature #{self.generate_token}"

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

  def list_products
    self.request(Net::HTTP::Get, "products")
  end

  def list_subscriptions(user:)
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

    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!! #{start_time} #{end_time}"
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    start_time_clause = "timestamp ge datetime'#{start_time.strftime(fmt)}'"

    end_time_clause = ""
    if end_time
      end_time_clause = " and timestamp le '#{end_time.strftime(fmt)}'"
    end

    self.request(Net::HTTP::Get, "reports/bySubscription", params: {
      "$filter": "#{start_time_clause}#{end_time_clause}"
    })
  end
end
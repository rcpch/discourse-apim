require "base64"
require "net/http"

# @@apim_base = 'https://rcpch-apim.management.azure-api.net/subscriptions/99e313f5-79fe-4480-b867-8daf2800cf22/resourceGroups/RCPCH-Dev-API-Growth/providers/Microsoft.ApiManagement/service/rcpch-apim'

class AzureAPIMError < StandardError
  def initialize(msg, code=Nil)
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

  def self.get_json(endpoint)
    url = UrlHelper.encode_and_parse("#{AzureAPIM.base_url}/#{endpoint}?api-version=2022-08-01")

    request =  Net::HTTP::Get.new(url)
    request['Authorization'] = "SharedAccessSignature #{AzureAPIM.generate_token}"

    response = Net::HTTP.start(url.host, url.port, :use_ssl => true) do |http|
      http.request(request)
    end

    json = JSON.parse(response.body)

    puts "!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "!!!!!!!! #{json}"
    puts '!!!!!!!!!!!!!!!!!!!!!!!!'

    if json['error']
      raise AzureAPIMError.new json['error']['message'] || 'Unknown AzureAPIM error', json['error']['code']
    else
      json['value']
    end
  end

  def self.list_products
    AzureAPIM.get_json("products")
  end
end
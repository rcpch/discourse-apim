require 'net/http'
require_relative '../../services/azure_apim'

class ApikeysController < ::ApplicationController
  @@apim_base = 'https://rcpch-apim.management.azure-api.net/subscriptions/99e313f5-79fe-4480-b867-8daf2800cf22/resourceGroups/RCPCH-Dev-API-Growth/providers/Microsoft.ApiManagement/service/rcpch-apim'

  def azure_safe_username(username)
    user = User.find_by_username(username)
    email = user.email
    
    email.gsub(/[^A-Z,a-z]+/, "-")
  end

  def list
    products = AzureAPIM.list_products.select { |product|
      product["properties"]["state"] == "published"
    }
    
    ret = products.map { |product|
      {
        "name": product["properties"]["displayName"] || product["name"],
        "key": params[:username]
      }
    }

    render json: ret
  end

  def create
    user = User.find_by_username(params[:username])
    email = user.email
    
    azure_safe_username = email.gsub(/[^A-Z,a-z]+/, "-")

    # uri = URI.parse("https://rcpch-apim.management.azure-api.net/subscriptions/99e313f5-79fe-4480-b867-8daf2800cf22/resourceGroups/RCPCH-Dev-API-Growth/providers/Microsoft.ApiManagement/service/rcpch-apim/users/mtest-rcpch-ac-uk?api-version=2022-08-0")
    # request = Net::HTTP::Put.new(uri)
    # request["Accept"] = "application/json"

    # req_options = {
    #   use_ssl: uri.scheme == "https",
    # }

    # response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    #   http.request(request)
    # end

    # render_json_dump JSON.parse(response.body)

    fake_api_key = {}
    fake_api_key['product'] = 'Growth Charts'
    fake_api_key['key'] = azure_safe_username

    ret = {}
    ret['api_keys'] = [fake_api_key]

    render json: ret
  end
end
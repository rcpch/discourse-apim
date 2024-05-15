require 'net/http'
require_relative '../../services/azure_apim'

class ApikeysController < ::ApplicationController
  @@apim_base = 'https://rcpch-apim.management.azure-api.net/subscriptions/99e313f5-79fe-4480-b867-8daf2800cf22/resourceGroups/RCPCH-Dev-API-Growth/providers/Microsoft.ApiManagement/service/rcpch-apim'

  def azure_safe_username(email)
    email.gsub(/[^A-Z,a-z]+/, "-")
  end

  def user_has_key_for_product(product, subscriptions)
    subscriptions.find { |subscription|
      subscription["properties"]["scope"] == product["id"]
    } != nil
  end

  def list
    user = current_user
    username = self.azure_safe_username(user.email)

    # Everything you could have an API key for
    products = AzureAPIM.list_products

    # What you actually have an API key for
    # If you've never signed up you won't have a user in Azure
    subscriptions = []

    begin
      subscriptions = AzureAPIM.list_subscriptions(user: username)
    rescue AzureAPIMError => e
      if e.code != "ResourceNotFound"
        raise e
      end
    end

    published_products = products.select { |product|
      product["properties"]["state"] == "published"
    }

    products_for_user = published_products.map { |product|
      {
        "name": product["name"],
        "displayName": product["properties"]["displayName"] || product["name"],
        "enabled": self.user_has_key_for_product(product, subscriptions)
      }
    } 
    
    ret = {
      "api_keys": products_for_user
    }

    render json: ret
  end

  def create
    user = current_user
    username = self.azure_safe_username(user.email)

    AzureAPIM.create_or_update_user(
      user: username,
      email: user.email,
      # Required by Azure but we don't need them
      first_name: "placeholder",
      last_name: "placeholder"
    )

    AzureAPIM.create_subscription_to_product(
      user: username,
      email: user.email,
      product: params[:product]
    )

    head 201
  end
end
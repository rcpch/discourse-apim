require 'net/http'
require_relative '../../services/azure_apim'
require_relative '../../services/usage_reporting'
require_relative '../../services/apim_usage_db'

class ApimController < ::ApplicationController
  def azure_safe_username(email)
    email.gsub(/[^A-Z,a-z]+/, "-")
  end

  def subscription_for_product(product, subscriptions)
    subscriptions.find { |subscription|
      subscription["properties"]["scope"] == product["id"]
    }
  end

  def usage_for_subscription(subscription)
    subscription_name = subscription["id"].split('/')[-1]
    usage = APIMUsageDB.get_all_monthly_usage_rows(subscription: subscription_name)

    usage.map { |row|
      {
        :month => row["month"],
        :count => row["callCountSuccess"]
      }
    }
  end

  def list
    user = current_user
    username = self.azure_safe_username(user.email)

    apim = AzureAPIM.instance

    # Everything you could have an API key for
    products = apim.list_products

    # What you actually have an API key for
    # If you've never signed up you won't have a user in Azure
    subscriptions = []

    begin
      subscriptions = apim.list_subscriptions_for_user(user: username)
    rescue AzureAPIMError => e
      if e.code != "ResourceNotFound"
        raise e
      end
    end

    published_products = products.select { |product|
      product["properties"]["state"] == "published"
    }

    products_for_user = published_products.map { |product|
      subscription = subscription_for_product(product, subscriptions)
      usage = usage_for_subscription(subscription) if subscription

      {
        "product" => product["name"],
        "displayName" => product["properties"]["displayName"] || product["name"],
        "enabled" => subscription != nil,
        "usage" => usage
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

    apim = AzureAPIM.instance

    # Required by Azure but we don't need them
    # Fill them in with data that doesn't look bad in their UI
    first_name, last_name = user.email.split("@")

    apim.create_or_update_user(
      user: username,
      email: user.email,
      first_name: first_name,
      last_name: last_name || first_name
    )

    apim.create_subscription_to_product(
      user: username,
      email: user.email,
      product: params[:product]
    )

    head 201
  end

  def show
    user = current_user
    username = self.azure_safe_username(user.email)

    ret = AzureAPIM.instance.show_api_keys(
      user: username,
      product: params[:product]
    )

    render json: ret
  end
end
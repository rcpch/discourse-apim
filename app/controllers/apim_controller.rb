require 'net/http'
require_relative '../../services/azure_apim'
require_relative '../../services/usage_reporting'
require_relative '../../services/apim_usage_db'

class ApimController < ::ApplicationController
  def find_group(param_name, ensure_can_see: true)
    name = params.require(param_name)
    group = Group.find_by("LOWER(name) = ?", name.downcase)
    raise Discourse::NotFound if ensure_can_see && !guardian.can_see_group?(group)
    group
  end

  def azure_username(object, default:)
    apim_fields = object.custom_fields['apim'] ||= {}
    username = apim_fields[:username]
    
    if !username
      username = default.gsub(/[^A-Z,a-z]+/, "-")
      apim_fields[:username] = username

      object.custom_fields['apim'] = apim_fields
      object.save_custom_fields
    end

    username
  end

  def azure_username_for_current_user()
    self.azure_username(current_user, default: current_user.email)
  end

  def azure_username_for_group()
    group = find_group(:id)
    self.azure_username(group, default: group.name)
  end

  def subscriptions_for_azure_user(username)
    begin
      AzureAPIM.instance.list_subscriptions_for_user(user: username)
    rescue AzureAPIMError => e
      # If you've never signed up you won't have a user in Azure
      if e.code != "ResourceNotFound"
        raise e
      end

      []
    end
  end

  def subscription_for_product(product, subscriptions)
    subscriptions.find { |subscription|
      subscription["properties"]["scope"] == product["id"]
    }
  end

  def subscription_for_product_name(product_name, subscriptions)
    subscriptions.find { |subscription|
      subscription["properties"]["scope"].end_with?("/#{product_name}")
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

  def list(azure_username:, product_state:)
    # Everything you could have credentials for
    products = AzureAPIM.instance.list_products

    # What you actually have credentials for
    subscriptions = self.subscriptions_for_azure_user(azure_username)

    published_products = products.select { |product|
      product["properties"]["state"] == product_state &&
        # hide weird azure defaults
        (!["starter", "unlimited"].include?(product["name"]))
    }

    # TODO MRB: show everything to admins, only show enabled ones to normal group members
    product_data = published_products.map { |product|
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
      "api_keys": product_data
    }

    render json: ret
  end

  def list_for_user
    self.list(
      azure_username: self.azure_username_for_current_user,
      product_state: "published"
    )
  end

  def list_for_group
    self.list(
      azure_username: self.azure_username_for_group,
      product_state: "notPublished"
    )
  end

  def create_for_user
    user = current_user
    username = self.azure_username(user)

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

  def show_for_user
    subscriptions = self.subscriptions_for_azure_user(self.azure_username_for_current_user)
    subscription = self.subscription_for_product_name(params[:product], subscriptions)

    return head 404 unless subscription

    ret = AzureAPIM.instance.show_api_keys(
      sid: subscription['name']
    )

    render json: ret
  end
end
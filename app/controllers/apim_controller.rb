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
    azure_username(current_user, default: current_user.email)
  end

  def azure_username_for_group(group)
    azure_username(group, default: group.name)
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

  def build_product_data(product, subscription)
    usage = usage_for_subscription(subscription) if subscription

    {
      "product" => product["name"],
      "displayName" => product["properties"]["displayName"] || product["name"],
      "enabled" => subscription != nil,
      "usage" => usage
    }
  end

  def is_weird_azure_default_product(product)
    ["starter", "unlimited"].include?(product["name"])
  end

  def list(azure_username, &include_product)
    # Everything you could have credentials for
    products = AzureAPIM.instance.list_products
      .select { |product| !is_weird_azure_default_product(product) }

    # What you actually have credentials for
    subscriptions = subscriptions_for_azure_user(azure_username)

    subscriptions_by_product = products.map { |product|
      [product, subscription_for_product(product, subscriptions)]
    }

    subscriptions_by_product.filter_map { |product, subscription|
      build_product_data(product, subscription) if include_product.call(product, subscription)
    }
  end

  def list_for_user
    product_data = list(azure_username_for_current_user) { |product|
      product["properties"]["approvalRequired"] == false
    }

    ret = {
      "api_keys": product_data
    }

    render json: ret
  end

  def list_for_group
    # checks we are a member or can admin this group
    group = find_group(:id)
    username = azure_username_for_group(group)

    product_data = list(username) { |product, subscription|
      guardian.is_admin? || subscription != nil
    }

    reporting_subscriptions = nil
    if guardian.is_admin?
      custom_apim_fields = group.custom_fields['apim'] ||= {}
      reporting_subscriptions = custom_apim_fields['reporting_subscriptions'] ||= []
    end

    ret = {
      "api_keys": product_data,
      "reporting_subscriptions": reporting_subscriptions
    }

    render json: ret
  end

  def create_for_user
    user = current_user
    username = azure_username_for_current_user

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

  def create_for_group
    # only admins can create on behalf of paying customers
    return head 403 unless guardian.is_admin?

    group = find_group(:id)
    username = azure_username_for_group(group)

    # Required by Azure but we don't need them
    # Fill them in with data that doesn't look bad in their UI
    first_name = group.name
    last_name = "discourse group"
    email = "#{username}@discourse-group-placeholders.rcpch.ac.uk"

    apim = AzureAPIM.instance

    apim.create_or_update_user(
      user: username,
      email: email,
      first_name: first_name,
      last_name: last_name
    )

    subscription_name = apim.create_subscription_to_product(
      user: username,
      email: email,
      product: params[:product]
    )

    custom_apim_fields = group.custom_fields['apim'] ||= {}
    reporting_subscriptions = custom_apim_fields['reporting_subscriptions'] ||= []

    reporting_subscriptions.append({
      :name => subscription_name
    })

    group.save_custom_fields

    head 201
  end

  def show_for_user
    subscriptions = subscriptions_for_azure_user(azure_username_for_current_user)
    subscription = subscription_for_product_name(params[:product], subscriptions)

    return head 404 unless subscription

    ret = AzureAPIM.instance.show_api_keys(
      sid: subscription['name']
    )

    render json: ret
  end

  def show_for_group
    group = find_group(:id)
    username = azure_username_for_group(group)

    subscriptions = subscriptions_for_azure_user(username)

    subscription = subscription_for_product_name(params[:product], subscriptions)

    return head 404 unless subscription

    ret = AzureAPIM.instance.show_api_keys(
      sid: subscription['name']
    )

    render json: ret
  end

  def set_reporting_subscriptions
    return head 403 unless guardian.is_admin?

    group = find_group(:id)

    reporting_subscriptions = params[:subscriptions]

    custom_apim_fields = group.custom_fields['apim'] ||= {}
    custom_apim_fields['reporting_subscriptions'] = reporting_subscriptions

    group.custom_fields['apim'] = custom_apim_fields
    group.save_custom_fields

    head 204
  end
end
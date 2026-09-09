# Read-only smoke test against a real Azure APIM instance.
#
# Exercises every Azure Resource Manager call the plugin makes, so you can tell
# whether the identity you're authenticating as has the permissions the plugin
# needs. It creates and changes nothing.
#
# Run it from the Discourse root, with the plugin's site settings configured:
#
#   d/exec bundle exec rails runner plugins/discourse-apim/s/azure-smoke-test.rb
#
# Locally that authenticates as your own Azure CLI login (`az login`), which
# tells you the ARM calls themselves work but says nothing about the production
# VM's managed identity. On the production VM it authenticates as that managed
# identity, which is the thing you actually want to verify.

require_relative "../services/azure_apim"
require_relative "../services/usage_reporting"

def check(description, permission)
  print "#{description.ljust(46)} "
  result = yield
  count = result.is_a?(Array) ? " (#{result.length})" : ""
  puts "OK#{count}"
  result
rescue AzureAPIMError => e
  puts "FAILED [#{e.code || "no code"}]"
  puts "  #{e.message}"
  puts "  needs: #{permission}"
  nil
end

apim = AzureAPIM.instance

puts "Service:        #{SiteSetting.discourse_apim_azure_service_name}"
puts "Resource group: #{SiteSetting.discourse_apim_azure_resource_group_name}"
puts "Subscription:   #{SiteSetting.discourse_apim_azure_subscription_id}"
puts

token_source =
  begin
    apim.access_token_from_managed_identity ? "VM managed identity" : "Azure CLI (az login)"
  rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout
    "Azure CLI (az login)"
  end
puts "Authenticating via: #{token_source}"
puts

check("List products", "service/products/read") { apim.list_products }
subscriptions = check("List subscriptions", "service/subscriptions/read") { apim.list_subscriptions }
check("List users", "service/users/read") { apim.list_users }

check("Read usage reports", "service/reports/read") do
  apim.get_usage(start_time: Time.now.beginning_of_month, end_time: nil)
end

# The sharp one: Reader and most built-in roles do NOT include listSecrets, but
# the plugin can't show anybody an API key without it.
if subscriptions&.any?
  sid = subscriptions.first["name"]
  check("Show API keys for #{sid}", "service/subscriptions/listSecrets/action") do
    apim.show_api_keys(sid: sid)
  end
else
  puts "Show API keys                                  SKIPPED (no subscriptions to read)"
end

if SiteSetting.discourse_apim_azure_additional_reporting_service_name.present?
  puts
  additional = AzureAPIM.additional_reporting_instance
  check("Additional reporting: list subscriptions", "service/subscriptions/read") do
    additional.list_subscriptions
  end
end

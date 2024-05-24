require 'csv'

class UsageReporting
  def self.redis_key(row)
    "apim:monthly:#{row[:month]}:#{row[:subscription]}"
  end

  def self.generate_report_object(usage_data_list, metadata)
    ret = {}

    usage_data_list.each { |usage_data|
      subscription_name = usage_data["subscriptionId"].split("/")[-1]
      
      metadata_fields = metadata[subscription_name] || {
        :display_name => '',
        :email => '',
        :owner_name => ''
      }

      metadata_fields[:subscription] = subscription_name

      # https://learn.microsoft.com/en-us/rest/api/apimanagement/reports/list-by-subscription?view=rest-apimanagement-2022-08-01&tabs=HTTP#reportrecordcontract
      fields_to_save = [
        "callCountTotal",
        # 2XX, 3XX
        "callCountSuccess",
        # 4XX
        "callCountBlocked",
        # 5XX
        "callCountFailed",
        # ??? (the docs say "Number of other calls" lol)
        "callCountOther",
        # Elapsed time (I think)
        "apiTimeMin",
        "apiTimeMax",
        "apiTimeAvg",
        # Backend time
        "serviceTimeMin",
        "serviceTimeMax",
        "serviceTimeAvg"
      ]

      if usage_data['callCountTotal'] > 0
        usage_fields = usage_data.slice(*fields_to_save)

        ret[subscription_name] = metadata_fields.merge(usage_fields)
      end
    }
    
    ret
  end

  def self.generate_report_csv(monthly_report_objects)
    headers = monthly_report_objects[0].keys

    ret = [
      CSV.generate_line(headers)
    ]

    monthly_report_objects[1..].each { |report_object|
      ret.append(CSV.generate_line(report_object.values))
    }

    # generate_line does the newlines for us
    ret.join('')
  end

  def self.get_subscription_metadata(apim)
    subscription_metadata = {}

    subscriptions = apim.list_subscriptions
    users = apim.list_users

    subscriptions.to_h { |subscription|
      owner = users.find { |user| user['id'] == subscription['properties']['ownerId'] }

      display_name = subscription['properties']['displayName']
      email = owner['properties']['email'] if owner
      owner_name = "#{owner['properties']['firstName']} #{owner['properties']['lastName']}" if owner

      metadata = {
        :display_name => display_name,
        :email => email,
        :owner_name => owner_name
      }

      [subscription['name'], metadata]
    }
  end
end
require_relative '../../services/azure_apim'
require_relative '../../services/usage_reporting'

module Jobs
  class FetchMonthlyUsageData < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      metadata = UsageReporting.get_subscription_metadata(AzureAPIM.instance)

      if AzureAPIM.additional_reporting_instance
        metadata = metadata.merge(UsageReporting.get_subscription_metadata(AzureAPIM.additional_reporting_instance))
      end

      (0..12).map { |n|
        start_time = Time.now.beginning_of_month - n.months
        end_time = n == 0 ? nil : start_time.end_of_month

        month = start_time.strftime("%Y-%m")

        base_fields = {
          :month => month,
          :start_time => start_time,
          :end_time => end_time
        }

        primary = AzureAPIM.instance.get_usage(
          start_time: start_time,
          end_time: end_time
        )

        additional = []

        if AzureAPIM.additional_reporting_instance
          additional = AzureAPIM.additional_reporting_instance.get_usage(
            start_time: start_time,
            end_time: end_time
          )
        end

        report = UsageReporting.generate_report([primary, additional].flatten, metadata)

        report.values.each { |row|
          data = base_fields.merge(row)
          json_data = data.to_json

          key = UsageReporting.redis_key(data)
          
          Discourse.redis.set(key, json_data)
        }
      }
    end
  end
end
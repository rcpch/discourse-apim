require 'csv'
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

      ret = []

      (0..12).map { |n|
        start_time = Time.now.beginning_of_month - n.months
        end_time = n == 0 ? nil : start_time.end_of_month

        key = start_time.strftime("%Y-%m")

        base_fields = {
          "key": key,
          "start_time": start_time,
          "end_time": end_time
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
          ret.append(base_fields.merge(row))
        }
      }

      # header
      puts CSV.generate_line ret[0].keys
      ret.each { |row|
        puts CSV.generate_line(row.values)
      }
    end
  end
end
require_relative '../../services/azure_apim'
require_relative '../../services/usage_reporting'
require_relative '../../services/apim_usage_db'

module Jobs
  class FetchMonthlyUsageData < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options queue: "low"

    def execute(args)
      return unless SiteSetting.discourse_apim_reporting_enabled

      metadata = UsageReporting.get_subscription_metadata(AzureAPIM.instance)

      if AzureAPIM.additional_reporting_instance
        additional_metadata = UsageReporting.get_subscription_metadata(AzureAPIM.additional_reporting_instance)

        metadata = metadata.merge(additional_metadata)
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

        report = UsageReporting.generate_report_object([primary, additional].flatten, metadata)

        report.values.each { |row|
          data = base_fields.merge(row)
          
          APIMUsageDB.save_monthly_usage_row(data)
        }
      }
    end
  end
end
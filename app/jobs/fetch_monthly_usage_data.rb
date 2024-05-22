require_relative '../../services/azure_apim'
require_relative '../../services/usage_reporting'

module Jobs
  class FetchMonthlyUsageData < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      ret = []

      (0..12).map { |n|
        start_time = Time.now.beginning_of_month - n.months
        end_time = n == 0 ? nil : start_time.end_of_month

        key = start_time.strftime("%Y-%m")

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

        report = generate_report([primary, additional].flatten)

        ret.append({
          "key": key,
          "start_time": start_time,
          "end_time": end_time,
          "usage": report
        })
      }
    end
  end
end
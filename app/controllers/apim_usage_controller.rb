require_relative '../../services/apim_usage_db'

class ApimUsageController < Admin::AdminController
  def report
    monthly_report_objects = APIMUsageDB.get_all_monthly_usage_rows

    if request.format == 'text/csv'
      ret = UsageReporting.generate_report_csv(monthly_report_objects)
      render body: ret, content_type: 'text/csv'
    else
      render json: monthly_report_objects
    end
  end

  def refresh
    Jobs.enqueue(:fetch_monthly_usage_data)
  end
end
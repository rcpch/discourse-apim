class ApimUsageController < Admin::AdminController
  def report
    keys = Discourse.redis.keys('apim:monthly*') 
    string_data = Discourse.redis.mget(*keys)

    monthly_report_objects = string_data.map { |data| JSON.parse(data) }

    if request.format == 'text/csv'
      ret = UsageReporting.generate_report_csv(monthly_report_objects)
      render inline: ret, content_type: 'text/csv'
    else
      render json: monthly_report_objects
    end
  end

  def refresh
    Jobs.enqueue(:fetch_monthly_usage_data)
  end
end
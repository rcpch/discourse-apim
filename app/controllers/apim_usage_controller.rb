class ApimUsageController < Admin::AdminController
  def report
    keys = Discourse.redis.keys('apim:monthly*') 
    string_data = Discourse.redis.mget(*keys)

    ret = string_data.map { |data| JSON.parse(data) }
    render json: ret
  end

  def refresh
    Jobs.enqueue(:fetch_monthly_usage_data)
  end
end
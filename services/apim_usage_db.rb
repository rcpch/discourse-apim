# TODO:
#  - Store as Rails models so we can query them with the data explorer
#  - Store a "last updated" field to show in the UI
#  - Store a lifecycle integer to ensure we're seeing consistent data
#    - Two phase: only increment to new lifecycle once all data is saved for the old

class APIMUsageDB
  def self.monthly_redis_key(row)
    "apim:monthly:#{row[:subscription]}:#{row[:month]}"
  end

  def self.save_monthly_usage_row(row)
    key = APIMUsageDB.monthly_redis_key(row)

    Discourse.redis.set(key, row.to_json)
  end

  def self.get_monthly_usage_row(month, subscription)
    key = APIMUsageDB.monthly_redis_key({ :month => month, :subscription => subscription })

    string_data = Discourse.redis.get(key)

    JSON.parse(string_data)
  end

  def self.get_all_monthly_usage_rows(subscription: nil)
    filter = "apim:monthly:#{subscription or ''}*"

    keys = Discourse.redis.keys(filter)

    if keys.empty?
      return []
    end

    string_data = Discourse.redis.mget(*keys)

    string_data.map { |data| JSON.parse(data) }
  end
end
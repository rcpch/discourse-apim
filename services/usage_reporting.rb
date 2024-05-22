def generate_report(usage_data_list)
  ret = {}

  usage_data_list.each { |usage_data|
    subscriptionId = usage_data['subscriptionId']
    
    # https://learn.microsoft.com/en-us/rest/api/apimanagement/reports/list-by-subscription?view=rest-apimanagement-2022-08-01&tabs=HTTP#reportrecordcontract
    callCountTotal = usage_data['callCountTotal']

    if callCountTotal > 0
      ret[subscriptionId] = {
        # 2XX, 3XX
        "callCountSuccess": usage_data['callCountSuccess'],
        # 4XX
        "callCountBlocked": usage_data['callCountBlocked'],
        # 5XX
        "callCountFailed": usage_data['callCountFailed'],
        # ??? (the docs say "Number of other calls" lol)
        "callCountOther": usage_data['callCountOther']
      }
    end
  }
  
  ret
end
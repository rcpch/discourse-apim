def generate_report(usage_data_list)
  ret = {}

  usage_data_list.each { |usage_data|
    subscription_id = usage_data["subscriptionId"]

    # https://learn.microsoft.com/en-us/rest/api/apimanagement/reports/list-by-subscription?view=rest-apimanagement-2022-08-01&tabs=HTTP#reportrecordcontract
    fields_to_save = [
      "callCountTotal",
      # 2XX, 3XX
      "callCountSuccess",
      # 4XX
      ":callCountBlocked",
      # 5XX
      ":callCountFailed",
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
      ret[subscription_id] = usage_data.slice(*fields_to_save)
    end
  }
  
  ret
end
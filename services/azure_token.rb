require "base64"

class AzureToken
  def self.generate
    identifier = "integration"
    key = "TODO CONFIG"
    
    expiry = (Time.now + (60 * 60)).strftime("%Y-%m-%dT%H:%M:%S.0000000Z")
    string_to_sign = "#{identifier}\n#{expiry}"
    
    digest = OpenSSL::HMAC.digest("SHA512", key, string_to_sign)
    sn = Base64.strict_encode64(digest)
    
    return "uid=integration&ex=#{expiry}&sn=#{sn}"
  end
end
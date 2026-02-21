require "base64"
require "openssl"

class AzureToken
  def initialize(identifier:, management_key:, expires_at:)
    @identifier = identifier
    @management_key = management_key
    @expires_at = expires_at
  end

  def to_s
    expiry = format_expiry(@expires_at)
    string_to_sign = "#{@identifier}\n#{expiry}"

    digest = OpenSSL::HMAC.digest("SHA512", @management_key, string_to_sign)
    sn = Base64.strict_encode64(digest)

    "uid=#{@identifier}&ex=#{expiry}&sn=#{sn}"
  end

  private

  def format_expiry(value)
    return value if value.is_a?(String)

    value.utc.strftime("%Y-%m-%dT%H:%M:%S.0000000Z")
  end
end

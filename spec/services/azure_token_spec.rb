require_relative "../../services/azure_token"

RSpec.describe AzureToken do
  it "generates a deterministic shared access signature token" do
    token = described_class.new(
      identifier: "integration",
      management_key: "secretkey",
      expires_at: Time.utc(2026, 1, 2, 3, 4, 5)
    )

    expected = "uid=integration&ex=2026-01-02T03:04:05.0000000Z&sn=GwcOndmhAXe8Wlha6gPpQzT2K4Bw8Y8Gw182HjMq8DHSrJdZyZUsKVrT/NhjrwK+3Had1Yt/vI/rNymmhOmVSQ=="

    expect(token.to_s).to eq(expected)
  end
end

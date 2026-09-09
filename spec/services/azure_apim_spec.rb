# frozen_string_literal: true

RSpec.describe AzureAPIM do
  let(:subscription_id) { "00000000-0000-0000-0000-000000000000" }
  let(:resource_group_name) { "rcpch-rg" }
  let(:service_name) { "rcpch-apim" }

  let(:apim) do
    AzureAPIM.new(
      service_name: service_name,
      subscription_id: subscription_id,
      resource_group_name: resource_group_name,
    )
  end

  let(:metadata_url) do
    "http://169.254.169.254/metadata/identity/oauth2/token" \
      "?api-version=2018-02-01&resource=https://management.azure.com/"
  end

  let(:arm_base_url) do
    "https://management.azure.com/subscriptions/#{subscription_id}" \
      "/resourceGroups/#{resource_group_name}" \
      "/providers/Microsoft.ApiManagement/service/#{service_name}"
  end

  describe "#get_access_token" do
    it "uses the token from the VM's managed identity when there is one" do
      stub_request(:get, metadata_url).with(headers: { "Metadata" => "true" }).to_return(
        status: 200,
        body: { access_token: "imds-token", expires_in: "86399" }.to_json,
      )

      # If we shell out to the CLI when a managed identity is available, that's a bug:
      # in production the CLI isn't installed and this would be a hard failure.
      expect(apim).not_to receive(:access_token_from_cli)

      expect(apim.get_access_token).to eq("imds-token")
    end

    it "falls back to the Azure CLI when there is no metadata service (eg. local dev)" do
      stub_request(:get, metadata_url).to_raise(Errno::EHOSTUNREACH)

      allow(apim).to receive(:`).with(/az account get-access-token/).and_return(
        { accessToken: "cli-token" }.to_json,
      )

      expect(apim.get_access_token).to eq("cli-token")
    end

    it "falls back to the Azure CLI when the metadata service has no identity to offer" do
      # What the IMDS returns when the VM has no managed identity assigned. Without
      # this the JSON parses fine but has no access_token, and we'd send `Bearer `.
      stub_request(:get, metadata_url).to_return(
        status: 400,
        body: {
          error: "invalid_request",
          error_description: "Identity not found",
        }.to_json,
      )

      allow(apim).to receive(:`).with(/az account get-access-token/).and_return(
        { accessToken: "cli-token" }.to_json,
      )

      expect(apim.get_access_token).to eq("cli-token")
    end

    it "only pays the metadata service timeout once, then remembers to use the CLI" do
      stub_request(:get, metadata_url).to_raise(Errno::EHOSTUNREACH)

      allow(apim).to receive(:`).with(/az account get-access-token/).and_return(
        { accessToken: "cli-token" }.to_json,
      )

      3.times { apim.get_access_token }

      expect(WebMock).to have_requested(:get, metadata_url).once
    end

    it "raises an actionable error when neither a managed identity nor the CLI is available" do
      stub_request(:get, metadata_url).to_raise(Errno::EHOSTUNREACH)

      # What you get when the Azure CLI isn't installed, or is installed but logged out.
      allow(apim).to receive(:`).with(/az account get-access-token/).and_return("")

      expect { apim.get_access_token }.to raise_error(AzureAPIMError, /managed identity/)
    end
  end

  describe "#request" do
    before do
      stub_request(:get, metadata_url).to_return(
        status: 200,
        body: { access_token: "imds-token" }.to_json,
      )
    end

    it "calls Azure Resource Manager with a bearer token, not the retired direct API" do
      stub_request(:get, "#{arm_base_url}/products?api-version=2022-08-01").with(
        headers: {
          "Authorization" => "Bearer imds-token",
        },
      ).to_return(status: 200, body: { value: [{ "name" => "growth-charts" }] }.to_json)

      expect(apim.list_products).to eq([{ "name" => "growth-charts" }])
    end

    it "surfaces Azure's error code and message" do
      stub_request(:get, "#{arm_base_url}/products?api-version=2022-08-01").to_return(
        status: 403,
        body: {
          error: {
            code: "AuthorizationFailed",
            message: "The client does not have authorization to perform action.",
          },
        }.to_json,
      )

      expect { apim.list_products }.to raise_error(AzureAPIMError) do |error|
        expect(error.code).to eq("AuthorizationFailed")
        expect(error.message).to match(/does not have authorization/)
      end
    end

    it "refuses to silently truncate a paginated response" do
      stub_request(:get, "#{arm_base_url}/products?api-version=2022-08-01").to_return(
        status: 200,
        body: { value: [], nextLink: "#{arm_base_url}/products?$skip=1000" }.to_json,
      )

      expect { apim.list_products }.to raise_error(AzureAPIMError, /nextLink/)
    end
  end
end

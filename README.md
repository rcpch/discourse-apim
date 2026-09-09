# discourse-apim

RCPCH API access management within Discourse

## Setup

- Ensure Docker is installed and running
- Check out the main Discourse GitHub repo (https://github.com/discourse/discourse)
- Check out this repository
- Create a symlink between the main Discourse repo and this repo
  - In the Discourse repo run `ln -s [location of this repo] plugins/discourse-apim`
- Follow the [Discourse Docker development instructions](https://meta.discourse.org/t/install-discourse-for-development-using-docker/102009#step-2-start-container-6)
  - `d/boot_dev --init`
  - Run the app: `d/exec bin/dev` (Discourse now serves the Rails backend and the Ember frontend from a single port; the old `d/rails s` + `d/ember-cli` pair is deprecated)
- Plugin JavaScript is compiled into `app/assets/generated/discourse-apim/` when the app boots, and the Ruby is loaded once at boot, so restart the server after changing either.
- Install the Azure CLI in the dev container so the plugin can authenticate against Azure APIM locally (there's no VM managed identity to fall back on outside of production - see below)
  - `d/exec /bin/bash` to get a shell
  - `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash` (https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
- Log in so the container can access the Azure APIs: `az login --use-device-code` and follow the instructions

## APISIX (Local Development)

- Start APISIX + etcd:
  - `s/apisix up -d`
- The APISIX config is mounted from `apisix.conf` to `/usr/local/apisix/conf/config.yaml` in the container.
- Create a test route:

```bash
curl -i -X PUT \
  "http://127.0.0.1:9180/apisix/admin/routes/getting-started-ip" \
  -H "X-API-KEY: arandomapikeyfordevelopment" \
  -H "Content-Type: application/json" \
  --data-raw '{
    "uri": "/ip",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "httpbin.org:80": 1
      }
    }
  }'
```

- Verify proxying:
  - `curl -i "http://127.0.0.1:9080/ip"`
- Useful commands:
  - `s/apisix logs -f apisix`
  - `s/apisix up -d --force-recreate` (reload after config changes)
  - `s/apisix down`

## Checking Azure connectivity and permissions

`s/azure-smoke-test.rb` exercises every Azure Resource Manager call the plugin makes and reports, per call, whether the identity you're authenticating as is allowed to make it. It creates and changes nothing. Run it from the Discourse root with the plugin's site settings configured:

```bash
d/exec bundle exec rails runner plugins/discourse-apim/s/azure-smoke-test.rb
```

Locally this authenticates as your own `az login`, which confirms the ARM calls work but tells you nothing about the production VM's managed identity. Run it *on the production VM* to check the managed identity itself.

Note that `listSecrets` - which the plugin needs in order to show anyone an API key - is not included in Reader or most other built-in roles. To check the role assignment from the Azure side without deploying anything:

```bash
# The principal ID of the VM's managed identity
az vm identity show --resource-group <rg> --name <vm> --query principalId -o tsv

# What that identity can do to the APIM service
az role assignment list --assignee <principalId> --include-inherited --include-groups \
  --scope /subscriptions/<subId>/resourceGroups/<rg>/providers/Microsoft.ApiManagement/service/<serviceName> \
  -o table
```

## Running the tests

```bash
s/test
```

The specs cover the managed identity / Azure CLI token logic, which otherwise only ever runs in production. They use WebMock and need no Azure access.

## Implemented

- Self service generate API credentials for individuals (ie our free tiers)
- Show monthly API usage for individuals
- Generate a monthly CSV of usage across all subscriptions

## Roadmap

- Combine customers with old and new subscriptions into a single row in the CSV
- Show monhtly API usage for paying customers (ie members of the appropriate Discourse group)
- Show existing API credentials to paying customers
- Regenerate new API credentials (internally saving old API keys for reference where appropriate)
- Support APIs using OAuth credentials

## Data Model

Each row in the plugin UI is a combination of three Azure APIM concepts:

- [User](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-create-or-invite-developers)
  - One to one mapping with a user in our Discourse forum
  - For Discourse groups (ie paying customers) we create a single user representing the group
- [Product](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-add-products?tabs=azure-portal)
  - One to one mapping with an API
  - Free products do not require approval and must have quota or rate limiting
  - Paid for products require approval and are only shown to users within a customer group in Discourse
- [Subscription](https://learn.microsoft.com/en-us/azure/api-management/api-management-subscriptions)
  - Essentially the API key, the mechanism for a user to consume a product
  - Each user (including customer group ones) should have only one subscription per product
  - They may however have older ones that are no longer active or come from an old APIM instance

From now on if we refer to "User" below it can be both users that represent individuals on the free tier and a user representing a group.

The Discourse plugin talks to Azure APIM through the [Azure Resource Manager REST API](https://learn.microsoft.com/en-us/rest/api/apimanagement/apimanagementrest/api-management-rest) (the older direct APIM management API, and the shared access signature keys it used, were [retired in March 2025](https://learn.microsoft.com/en-us/azure/api-management/breaking-changes/direct-management-api-retirement-march-2025)). We authenticate with an access token for the production VM's [managed identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token), which needs an RBAC role assignment (eg. API Management Service Contributor) on the resource group. Locally there's no managed identity to use, so the plugin falls back to `az account get-access-token` - hence the Azure CLI setup step above.

To generate the list of APIs we combine the following API calls:

- [Product - List By Service](https://learn.microsoft.com/en-us/rest/api/apimanagement/product/list-by-service?view=rest-apimanagement-2022-08-01&tabs=HTTP).
  - For individual users we filter by products that do not require approval so they can only sign up to our free products.
  - For a paid customer group we show the products they have been signed up for
  - For administrators viewing either we show all products regardless, allowing them to match as they see fit
- [User Subscription - List](https://learn.microsoft.com/en-us/rest/api/apimanagement/user-subscription/list?view=rest-apimanagement-2022-08-01&tabs=HTTP)
  - Contains a `scope` field against each subscription which we match against the products to show which ones they already have credentials for

To display API keys we can use:

- [Subscription - List Secrets](https://learn.microsoft.com/en-us/rest/api/apimanagement/subscription/list-secrets?view=rest-apimanagement-2022-08-01&tabs=HTTP)

To request a new API key is two API calls:

- [User - Create Or Update](https://learn.microsoft.com/en-us/rest/api/apimanagement/user/create-or-update?view=rest-apimanagement-2022-08-01&tabs=HTTP)
  - It's fine to call that on every request as if the user already exists
    it won't fail
  - The resource name is very picky but I think we can replace any non `[A-Z,a-z]`
    character from their email with `-`. That way we don't need to use the
    Discourse user ID in Azure APIM.
- [Subscription - Create Or Update](https://learn.microsoft.com/en-us/rest/api/apimanagement/subscription/create-or-update?view=rest-apimanagement-2022-08-01&tabs=HTTP)

We save the user IDs as a custom field on the appropriate Discourse user or group. This allows us to manually change them to accomodate those generated by hand in the Azure UI before this plugin was built.

We also need a list of additional subscription IDs so that we can calculate usage even if the subscription has been recreated or to accomodate subscriptions from a previous APIM instance in Azure.

To generate usage:

- [Reports - List By Subscription](https://learn.microsoft.com/en-us/rest/api/apimanagement/reports/list-by-subscription?view=rest-apimanagement-2022-08-01&tabs=HTTP)
  - Call this hourly with monthly time ranges back as far as we want to go
  - Persist the results (currently Redis, should be a normal Rails model in the future)
  - Calculate usage reports by pulling all the data out of the database
  - Show usage for an individual user by filtering by a given set of subscription IDs stored as custom fields 

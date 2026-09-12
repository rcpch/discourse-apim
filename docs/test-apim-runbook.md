# Runbook: a throwaway APIM instance for testing this plugin

This walks through standing up an Azure API Management instance that exists purely to test `discourse-apim`, with a mock Digital Growth Charts API and its own RBAC, so that development never points at the production `rcpch-apim`.

Everything here is scoped to a dedicated resource group, so teardown is a single command.

## Read this before you start: it is not free

There is no free API Management tier that will work for this plugin.

The Consumption tier has no base cost and includes 1 million calls a month, but [Microsoft's tier comparison](https://learn.microsoft.com/en-us/azure/api-management/api-management-features) shows it does not support **API analytics** or the **developer portal**. Those are not cosmetic for us:

- No API analytics means `reports/bySubscription` is unavailable, so the whole usage reporting half of the plugin (the scheduled job, the CSV, the per-user charts) cannot work.
- The developer portal row covers users and groups, which `create_or_update_user`, `list_users` and `list_subscriptions_for_user` all depend on.

So a Consumption instance would look like it provisioned fine and then fail in confusing ways.

The cheapest tier that actually works is **Developer**, at roughly 48 USD per month per unit. It is explicitly intended for non-production use and evaluation, and carries no SLA, which is exactly what we want. Check [the pricing page](https://azure.microsoft.com/pricing/details/api-management/) for the current figure in GBP before committing.

Developer tier is billed hourly, so if you only need it occasionally, create it for a test session and delete it afterwards (about 1.30 USD a day). The catch is that classic-tier provisioning takes **30 to 45 minutes**, so it is not something you can spin up on a whim. Decide up front whether you want it permanent or on demand.

## Prerequisites

- Azure CLI logged in: `az login`
- Permission to create resource groups and role assignments in the subscription. Creating role assignments needs `Microsoft.Authorization/roleAssignments/write`, which Owner and User Access Administrator have but Contributor does **not**.

Set these once per shell:

```bash
SUBSCRIPTION_ID=99e313f5-79fe-4480-b867-8daf2800cf22
RG=RCPCH-Test-APIM
APIM_NAME=rcpch-apim-test          # must be globally unique across Azure
LOCATION=uksouth

az account set --subscription "$SUBSCRIPTION_ID"
```

`APIM_NAME` becomes `https://<name>.azure-api.net`, so it has to be unique across all of Azure. If creation fails with a name conflict, pick another.

## Step 1: dedicated resource group

A separate resource group is what makes this safe to delete and easy to scope RBAC to.

```bash
az group create --name "$RG" --location "$LOCATION"
```

## Step 2: create the APIM instance

```bash
az apim create \
  --name "$APIM_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku-name Developer \
  --publisher-email "$(az account show --query user.name -o tsv)" \
  --publisher-name "RCPCH Test" \
  --no-wait
```

`--no-wait` returns immediately. Poll until it reports `Succeeded`:

```bash
az apim show --name "$APIM_NAME" --resource-group "$RG" --query provisioningState -o tsv
```

Go and do something else for half an hour. Nothing below will work until this returns `Succeeded`.

Once it is up, capture the resource ID, which is the RBAC scope you will use throughout:

```bash
APIM_ID=$(az apim show --name "$APIM_NAME" --resource-group "$RG" --query id -o tsv)
BASE="https://management.azure.com$APIM_ID"
AV="api-version=2022-08-01"
echo "$APIM_ID"
```

## Step 3: a mock Digital Growth Charts API

The Azure CLI has no `az apim api operation` or policy subcommands, so these steps go through ARM directly with `az rest`. A `mock-response` policy means there is no backend to run or pay for: APIM returns the example response defined on the operation.

Create the API:

```bash
az rest --method put --url "$BASE/apis/dgc-mock?$AV" --body '{
  "properties": {
    "displayName": "Digital Growth Charts (mock)",
    "path": "dgc",
    "protocols": ["https"],
    "subscriptionRequired": true,
    "serviceUrl": "https://example.invalid"
  }
}'
```

Add an operation with an example response. The example is what `mock-response` replays, so it has to be present:

```bash
az rest --method put --url "$BASE/apis/dgc-mock/operations/calculation?$AV" --body '{
  "properties": {
    "displayName": "Calculation",
    "method": "POST",
    "urlTemplate": "/calculation",
    "responses": [{
      "statusCode": 200,
      "description": "Mock centile calculation",
      "representations": [{
        "contentType": "application/json",
        "examples": {
          "default": {
            "value": {
              "measurement_type": "height",
              "centile": 50,
              "sds": 0.0,
              "note": "mock response, not a real calculation"
            }
          }
        }
      }]
    }]
  }
}'
```

Turn on mocking for that operation:

```bash
az rest --method put --url "$BASE/apis/dgc-mock/operations/calculation/policies/policy?$AV" --body '{
  "properties": {
    "format": "xml",
    "value": "<policies><inbound><base /><mock-response status-code=\"200\" content-type=\"application/json\" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>"
  }
}'
```

## Step 4: products mirroring production

The plugin lists products and filters out the two Azure ships by default (`starter` and `unlimited`). It only offers self-service signup for products where `approvalRequired` is false, so set that deliberately.

```bash
for p in free-growth intermediate-growth; do
  az rest --method put --url "$BASE/products/$p?$AV" --body "{
    \"properties\": {
      \"displayName\": \"Growth - ${p}\",
      \"description\": \"Test product for discourse-apim\",
      \"subscriptionRequired\": true,
      \"approvalRequired\": false,
      \"state\": \"published\"
    }
  }"
  az rest --method put --url "$BASE/products/$p/apis/dgc-mock?$AV" --body '{}'
done
```

Note `approvalRequired: false` and `state: published`. The plugin's `list_for_user` only shows products with `approvalRequired == false`, so if signup buttons do not appear, check this first.

## Step 5: the RBAC

Three pieces make up an Azure role assignment, and it is worth having the vocabulary straight:

- **Principal** - who is being granted access. For us, a managed identity (an Entra identity that Azure manages, with no password to handle).
- **Role definition** - what they may do. `API Management Service Contributor` grants `Microsoft.ApiManagement/service/*`, a wildcard that includes `subscriptions/listSecrets/action`. That last one matters: without it the plugin can list everything but cannot reveal a single API key, and most read-oriented roles do not include it.
- **Scope** - where it applies. Assignments inherit downwards, so a grant at resource group level covers every resource in it, now and in future.

Production today grants `API Management Service Contributor` at **resource group** scope on `RCPCH-Dev-API-Growth`. For the test instance, scope to the **individual resource** instead, which is the tighter thing to do:

```bash
FORUM_IDENTITY=$(az vm identity show \
  --resource-group RCPCH-DEV-AUDITTOOLS \
  --name forum.rcpch.tech \
  --query principalId -o tsv)

az role assignment create \
  --assignee-object-id "$FORUM_IDENTITY" \
  --assignee-principal-type ServicePrincipal \
  --role "API Management Service Contributor" \
  --scope "$APIM_ID"
```

`--assignee-principal-type ServicePrincipal` is not optional in practice. Without it the CLI tries to resolve the object ID against Entra, which intermittently fails for freshly created identities.

Confirm it landed:

```bash
az role assignment list --scope "$APIM_ID" --include-inherited \
  --query "[].{principalId:principalId, role:roleDefinitionName, scope:scope}" -o table
```

You will see inherited subscription-level assignments here too, including your own. That is expected, and it is exactly why the next step exists.

## Step 6: prove the role is sufficient, without the VM

This is the step people skip, and it is the one that actually answers "will this work in production".

Testing from your laptop authenticates as **you**. If you are an Owner, every call succeeds regardless of whether the managed identity's role is adequate, so a green run proves nothing about production. To test the permission set itself, create a service principal holding exactly the role under test and authenticate as that:

```bash
SP=$(az ad sp create-for-rbac \
  --name "discourse-apim-rbac-test" \
  --role "API Management Service Contributor" \
  --scopes "$APIM_ID" \
  -o json)

echo "$SP"   # contains a password: treat as a secret, do not commit
```

In a **separate shell** so you do not disturb your own login:

```bash
az login --service-principal \
  --username <appId from above> \
  --password <password from above> \
  --tenant dd8f9931-cb78-4406-8a01-01ac61c10d4a

# now run the plugin's smoke test as that principal
```

If `s/azure-smoke-test.rb` passes here, the role genuinely covers everything the plugin does. Delete the service principal when finished:

```bash
az ad sp delete --id <appId>
```

## Step 7: point the plugin at it

```bash
docker exec -u discourse -w /src discourse_dev bundle exec rails runner "
SiteSetting.discourse_apim_azure_service_name = '$APIM_NAME'
SiteSetting.discourse_apim_azure_subscription_id = '$SUBSCRIPTION_ID'
SiteSetting.discourse_apim_azure_resource_group_name = '$RG'
SiteSetting.discourse_apim_azure_additional_reporting_service_name = ''
"
```

Then run the smoke test, which exercises every ARM call the plugin makes and reports which the current identity is allowed:

```bash
docker exec -u discourse -w /src discourse_dev \
  bundle exec rails runner plugins/discourse-apim/s/azure-smoke-test.rb
```

Expect `List products`, `List subscriptions`, `List users` and `Read usage reports` to pass immediately. `Show API keys` will report `SKIPPED (no subscriptions to read)` until something has subscribed, which is fine: sign up through the plugin UI, then run it again to exercise `listSecrets`.

Usage reports will be empty until calls have actually flowed through the mock API. To generate some:

```bash
# create a subscription via the plugin UI first, then reveal its key and:
curl -s -X POST "https://$APIM_NAME.azure-api.net/dgc/calculation" \
  -H "Ocp-Apim-Subscription-Key: <key>" -H "Content-Type: application/json" -d '{}'
```

Analytics aggregation is not instant - allow 15 minutes or so before `reports/bySubscription` reflects the calls.

## Step 8: teardown

Deleting the resource group removes the APIM instance and the role assignment scoped to it:

```bash
az group delete --name "$RG" --yes --no-wait
```

APIM soft-deletes, holding the name for 48 hours. To reuse the name immediately, or to stop it counting against quota:

```bash
az apim deletedservice list -o table
az apim deletedservice purge --service-name "$APIM_NAME" --location "$LOCATION"
```

Do not forget the service principal from step 6 if you created one.

## Optional: tighten production while you are here

Production currently grants the forum VM's identity `API Management Service Contributor` across the whole `RCPCH-Dev-API-Growth` resource group, which covers every resource in it including any added later. Narrowing it to just the APIM resource is a small change with no downside:

```bash
PROD_APIM_ID=$(az apim show --name rcpch-apim \
  --resource-group RCPCH-Dev-API-Growth --query id -o tsv)

# add the narrower assignment first, verify the plugin still works, then remove the wider one
az role assignment create \
  --assignee-object-id "$FORUM_IDENTITY" \
  --assignee-principal-type ServicePrincipal \
  --role "API Management Service Contributor" \
  --scope "$PROD_APIM_ID"

az role assignment delete \
  --assignee "$FORUM_IDENTITY" \
  --role "API Management Service Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/RCPCH-Dev-API-Growth"
```

Add before removing, and verify in between - if you remove first and the new assignment has not propagated, the forum loses API key management until it does.

One thing to leave alone: the forum VM has both a system-assigned and a user-assigned identity. The plugin requests a token without naming one, and [Azure defaults to the system-assigned identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identities-faq) in that case, which is the one holding the role. If the system-assigned identity were ever disabled, the metadata service would face multiple user-assigned identities, require an explicit client ID, and the plugin would break.

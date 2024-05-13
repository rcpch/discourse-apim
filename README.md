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
  - Run the Rails backend in one terminal: `d/rails s`
  - Run the Ember frontend in another: `d/ember-cli`

## Scope

- Request new API credentials for our free to access APIs
- See existing API credentials (where security allows)
- Regenerate new API credentials 

## Not in scope

- Viewing API keys for paid tiers of access

## Data Model

We create an Azure APIM subscription (ie API key) per endpoint. We deliberately do
not use the ability to subscribe to an Azure APIM product as having a single API
key that can access multiple endpoints is confusing.

We will create an Azure API product defining free tier access for each API. This
is to enforce hard limits where appropriate.

We will not create products for paid access. In that case we manually create an
Azure APIM subscription and assign it to the API directly. We then share the
credentials directly with the paying customer as appropriate.

We will talk to the API management API directly:

- https://learn.microsoft.com/en-us/rest/api/apimanagement/apimanagementrest/api-management-rest
- https://learn.microsoft.com/en-us/rest/api/apimanagement/apimanagementrest/azure-api-management-rest-api-authentication#ProgrammaticallyCreateToken

To generate the list of APIs we will combine:

- [Product - List By Service](https://learn.microsoft.com/en-us/rest/api/apimanagement/product/list-by-service?view=rest-apimanagement-2022-08-01&tabs=HTTP)
- [User Subscription - List](https://learn.microsoft.com/en-us/rest/api/apimanagement/user-subscription/list?view=rest-apimanagement-2022-08-01&tabs=HTTP)

The latter contains a `scope` field against each subscription which we can use
to display to the user what APIs they have already requested credentials for.

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


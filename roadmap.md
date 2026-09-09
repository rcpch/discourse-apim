# Roadmap

## From README.md
- [ ] Combine customers with old and new subscriptions into a single row in the CSV
- [ ] Show monthly API usage for paying customers (members of the appropriate Discourse group)
- [ ] Show existing API credentials to paying customers
- [ ] Regenerate new API credentials (preserve old API keys for reference where appropriate)
- [ ] Support APIs using OAuth credentials

## From TODOs in Code
- [ ] Isolate plugin routes as a Rails engine
- [ ] Store usage data as Rails models so it can be queried in Data Explorer
- [ ] Store a "last updated" timestamp for usage data to display in the UI
- [ ] Add a lifecycle integer and two-phase updates to guarantee consistent usage data
- [ ] Investigate why `SimpleList` cannot accept a list directly (remove newline join workaround)

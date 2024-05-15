import Route from "@ember/routing/route";
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { ajax } from "discourse/lib/ajax";

class ApiKeyRow {
  @tracked apiKey;

  constructor(product, displayName, enabled) {
    this.product = product;
    this.displayName = displayName;
    this.enabled = enabled;
  }
}

export default class UserApiKeysRoute extends Route {
  async model() {
    const { api_keys } = await ajax(`${window.location.pathname}.json`);

    const rows = api_keys.map(({ product, displayName, enabled }) =>
      new ApiKeyRow(product, displayName, enabled)
    );

    return rows;
  }

  @action
  refreshModel() {
    this.refresh()
  }
}

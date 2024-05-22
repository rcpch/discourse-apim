import Route from "@ember/routing/route";
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

class ApimCredential {
  @tracked apiKey;

  constructor(product, displayName, enabled) {
    this.product = product;
    this.displayName = displayName;
    this.enabled = enabled;
  }
}

export default class UserApimRoute extends Route {
  async model() {
    const user = withPluginApi("1.31.0", api => api.getCurrentUser());
    const { username } = user;

    const resp = await ajax(`/apim/usage`);
    console.log({ resp });

    const { api_keys } = await ajax(`/apim/credentials/${username}`);

    const credentials = api_keys.map(({ product, displayName, enabled }) =>
      new ApimCredential(product, displayName, enabled)
    );

    return {
      user,
      credentials
    };
  }

  @action
  refreshModel() {
    this.refresh()
  }
}

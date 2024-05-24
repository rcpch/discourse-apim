import Route from "@ember/routing/route";
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

class ApimCredential {
  @tracked apiKey;

  constructor(product, displayName, enabled, usage) {
    this.product = product;
    this.displayName = displayName;
    this.enabled = enabled;
    this.usage = usage;
  }

  callsThisMonth = () => {
    const key = moment().format('YYYY-MM');
    const usageThisMonth = (this.usage ?? []).find(({ month }) => month == key);

    return usageThisMonth?.count ?? 0;
  }
}

export default class UserApimRoute extends Route {
  async model() {
    const user = withPluginApi("1.31.0", api => api.getCurrentUser());
    const { username } = user;

    const { api_keys } = await ajax(`/apim/credentials/${username}`);

    const credentials = api_keys.map(({ product, displayName, enabled, usage }) =>
      new ApimCredential(product, displayName, enabled, usage)
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

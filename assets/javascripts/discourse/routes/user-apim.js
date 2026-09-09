import { action } from '@ember/object';
import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import { ApimCredential } from "../lib/apim-credential";

export default class UserApimRoute extends Route {
  async model() {
    const user = withPluginApi(api => api.getCurrentUser());
    const { username } = user;

    const { api_keys } = await ajax(`/apim/users/${username}`);

    const credentials = api_keys.map(params => new ApimCredential(params));

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

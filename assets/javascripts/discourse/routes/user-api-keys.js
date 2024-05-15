import Route from "@ember/routing/route";
import { A } from '@ember/array';
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class UserApiKeysRoute extends Route {
  async model() {
    const { api_keys } = await ajax(`${window.location.pathname}.json`);

    return {
      api_keys: A(api_keys)
    }
  }

  @action
  refreshModel() {
    this.refresh()
  }
}

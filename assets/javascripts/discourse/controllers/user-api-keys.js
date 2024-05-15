import Controller from "@ember/controller";
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class UserApiKeysController extends Controller {
  @action
  async createApiKey(name) {
    console.log({ name, target: this.target, router: this.target.get('router') }, this);

    const { api_keys } = await ajax(`${window.location.pathname}/${name}`, {
      method: 'POST'
    });

    // apparently I have to send an action here rather than just getting the router and calling refresh
    // aren't javascript frameworks wonderful they really make life easy
    this.send("refreshModel");
  }
}


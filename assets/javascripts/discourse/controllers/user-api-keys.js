import Controller from "@ember/controller";
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class UserApiKeysController extends Controller {
  @action
  async createApiKey(product) {
    await ajax(`${window.location.pathname}/${product}`, {
      method: 'POST'
    });

    // apparently I have to send an action here rather than just getting the router and calling refresh
    // aren't javascript frameworks wonderful they really make life easy
    this.send("refreshModel");
  }

  @action
  async showApiKey(product) {
    const { primaryKey } = await ajax(`${window.location.pathname}/${product}/keys`, {
      method: 'POST'
    });

    const row = this.model.find(row => row.product === product);
    row.apiKey = primaryKey;

    console.log(this.model);
  }
}


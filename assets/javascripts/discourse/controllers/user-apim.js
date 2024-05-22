import Controller from "@ember/controller";
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

export default class UserApimController extends Controller {
  @action
  async createApiKey(product) {
    const { username } = this.model.user;

    await ajax(`/apim/credentials/${username}/${product}`, {
      method: 'POST'
    });

    // apparently I have to send an action here rather than just getting the router and calling refresh
    // aren't javascript frameworks wonderful they really make life easy
    this.send("refreshModel");
  }

  @action
  async showApiKey(product) {
    const { username } = this.model.user;

    const { primaryKey } = await ajax(`/apim/credentials/${username}/${product}/show`, {
      method: 'POST'
    });

    const credential = this.model.credentials.find(credential => credential.product === product);
    credential.apiKey = primaryKey;
  }
}


import Controller from "@ember/controller";
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsApimController extends Controller {
  @action
  async refresh() {
    await ajax(`/apim/usage/refresh`, {
      method: 'POST'
    });
  }
}


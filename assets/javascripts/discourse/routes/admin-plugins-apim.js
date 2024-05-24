import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsApimRoute extends Route {
  async model() {
    const resp = await ajax(`/apim/usage/report`);

    console.log({ resp });

    return resp;
  }
}

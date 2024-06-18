import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { ApimCredential } from "../lib/apim-credential";

export default class GroupApimRoute extends Route {
  async model() {
    const { name } = this.modelFor("group");
    const { api_keys } = await ajax(`/apim/credentials/group/${name}`);
    
    const credentials = api_keys.map(params => new ApimCredential(params));

    return {
      name,
      credentials
    };
  }
}

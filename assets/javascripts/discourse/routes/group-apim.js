import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class GroupApimRoute extends Route {
  async model() {
    const { name } = this.modelFor("group");
    const { api_keys } = await ajax(`/apim/credentials/group/${name}`);
    
    console.log('api_keys', { api_keys });
  }
}

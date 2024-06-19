import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { ApimCredential } from "../lib/apim-credential";

export default class GroupApimRoute extends Route {
  async model() {
    const { name } = this.modelFor("group");
    const { api_keys, additional_reporting_subscriptions } = await ajax(`/apim/groups/${name}`);
    
    const credentials = api_keys.map(params => new ApimCredential(params));

    return {
      name,
      credentials,
      // Handlebars doesn't have a sensible way to tell a field is missing vs an empty list
      showAdditionalReportingSubscriptions: additional_reporting_subscriptions?.length > -1,
      // TODO MRB: why can't I just pass a list here?!
      additionalReportingSubscriptions: (additional_reporting_subscriptions ?? []).join('\n')
    };
  }
}

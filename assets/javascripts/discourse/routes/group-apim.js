import Route from "@ember/routing/route";
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";
import { ApimCredential } from "../lib/apim-credential";

export default class GroupApimRoute extends Route {
  async model() {
    const { name } = this.modelFor("group");
    const { api_keys, reporting_subscriptions } = await ajax(`/apim/groups/${name}`);
    
    const credentials = api_keys.map(params => new ApimCredential(params));

    return {
      name,
      credentials,
      // Handlebars doesn't have a sensible way to tell a field is missing vs an empty list
      // Only admins can see this list
      showReportingSubscriptions: reporting_subscriptions?.length > -1,
      // TODO MRB: why can't I just pass a list here?!
      reportingSubscriptions: (reporting_subscriptions ?? [])
        .map(({ name }) => name)
        .join('\n')
    };
  }

  @action
  refreshModel() {
    this.refresh()
  }
}

import { action } from '@ember/object';
import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { ApimCredential } from "../../lib/apim-credential";

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
      reportingSubscriptions: (reporting_subscriptions ?? [])
        .map((subscription) => subscription.name)
    };
  }

  @action
  refreshModel() {
    this.refresh()
  }
}

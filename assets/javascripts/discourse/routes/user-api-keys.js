import Route from "@ember/routing/route";

export default class UserApiKeysRoute extends Route {
  model() {
    return {
      apiKeys: null
    };
  }
}

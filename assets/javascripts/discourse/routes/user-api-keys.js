import Route from "@ember/routing/route";
import { A } from '@ember/array';

export default class UserApiKeysRoute extends Route {
  model() {
    return {
      api_keys: A([])
    }
  }
}

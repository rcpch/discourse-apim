import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend({
  actions: {
    createApiKey: async function() {
      const { api_keys } = await ajax(window.location.pathname, {
        method: 'POST'
      });

      this.model.api_keys.pushObject(api_keys[0]);
    }
  }
});


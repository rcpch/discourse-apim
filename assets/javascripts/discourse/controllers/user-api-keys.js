import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend({
  actions: {
    createApiKey: async () => {
      const response = await ajax(window.location.pathname, {
        method: 'POST'
      });


      console.log('create API key', response);
    }
  }
});

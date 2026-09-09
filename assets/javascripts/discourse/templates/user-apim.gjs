import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ApimCredential from "../components/apim-credential";

export default RouteTemplate(
  <template>
    <div class="user-content apim" id="user-content">
      {{#each @model.credentials as |credential|}}
        <ApimCredential
          @credential={{credential}}
          @showApiKey={{fn @controller.showApiKey credential.product}}
          @createApiKey={{fn @controller.createApiKey credential.product}}
        />
      {{/each}}
    </div>
  </template>
);

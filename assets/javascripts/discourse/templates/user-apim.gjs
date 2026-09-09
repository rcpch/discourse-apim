import { fn } from "@ember/helper";
import ApimCredential from "../components/apim-credential";

export default <template>
  <div class="user-content apim" id="user-content">
    {{#each @controller.model.credentials as |credential|}}
      <ApimCredential
        @credential={{credential}}
        @showApiKey={{fn @controller.showApiKey credential.product}}
        @createApiKey={{fn @controller.createApiKey credential.product}}
      />
    {{/each}}
  </div>
</template>;

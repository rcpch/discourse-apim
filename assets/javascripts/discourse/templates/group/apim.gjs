import { fn, hash } from "@ember/helper";
import ListSetting from "discourse/select-kit/components/list-setting";
import ApimCredential from "../../components/apim-credential";

export default <template>
  <div class="user-content apim" id="user-content">
    {{#each @controller.model.credentials as |credential|}}
      <ApimCredential
        @credential={{credential}}
        @showApiKey={{fn @controller.showApiKey credential.product}}
        @createApiKey={{fn @controller.createApiKey credential.product}}
      />
    {{/each}}
    {{#if @controller.model.showReportingSubscriptions}}
      <div class="reporting-subscriptions">
        <div class="reporting-subscription-title">
          Additional reporting subscriptions (RCPCH administrators only)
        </div>
        API usage through these subscriptions will be assigned to this group.
        <ListSetting
          @value={{@controller.model.reportingSubscriptions}}
          @choices={{@controller.model.reportingSubscriptions}}
          @options={{hash allowAny=true}}
          @onChange={{@controller.setReportingSubscriptions}}
        />
      </div>
    {{/if}}
  </div>
</template>;

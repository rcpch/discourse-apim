import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import SimpleList from "select-kit/components/simple-list";
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
      {{#if @model.showReportingSubscriptions}}
        <div class="reporting-subscriptions">
          <div class="reporting-subscription-title">
            Additional reporting subscriptions (RCPCH administrators only)
          </div>
          API usage through these subscriptions will be assigned to this group.
          <SimpleList
            @values={{@model.reportingSubscriptions}}
            @onChange={{@controller.setReportingSubscriptions}}
          />
        </div>
      {{/if}}
    </div>
  </template>
);

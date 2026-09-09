import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

// The admin plugin chrome already renders the breadcrumbs and the plugin tab
// nav around this template, so we only contribute the title, description and
// actions here.
export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.apim.title"}}
    @descriptionLabel={{i18n "admin.config.apim.header_description"}}
    @hideTabs={{true}}
  >
    <:actions as |actions|>
      <actions.Primary
        @action={{@controller.refresh}}
        @label="admin.config.apim.actions.refresh_usage"
      />
      <actions.Default
        @action={{@controller.downloadReport}}
        @label="admin.config.apim.actions.download_report"
      />
    </:actions>
  </DPageHeader>
</template>;

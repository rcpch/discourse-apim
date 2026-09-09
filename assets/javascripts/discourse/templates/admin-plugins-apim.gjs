import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.apim.title"}}
      @descriptionLabel={{i18n "admin.config.apim.header_description"}}
      @hideTabs={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/plugins"
          @label={{i18n "admin.plugins.title"}}
        />
        <DBreadcrumbsItem
          @path="/admin/plugins/apim"
          @label={{i18n "admin.config.apim.title"}}
        />
      </:breadcrumbs>

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
  </template>
);

import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";

export default RouteTemplate(
  <template>
    <button {{on "click" @controller.refresh}} class="btn">Refresh Usage Data</button>
    <button {{on "click" @controller.downloadReport}} class="btn">Download Usage Report</button>
  </template>
);

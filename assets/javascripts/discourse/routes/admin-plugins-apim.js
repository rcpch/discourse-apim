import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default class AdminPluginsApimRoute extends DiscourseRoute {
  titleToken() {
    return I18n.t("admin.config.apim.title");
  }
}

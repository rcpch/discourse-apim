import Controller from "@ember/controller";
import { action } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsApimController extends Controller {
  @action
  async refresh() {
    await ajax(`/apim/usage/refresh`, {
      method: 'POST'
    });
  }

  @action
  async downloadReport() {
    // I struggled opening a new tab to download this directly:
    //   - It seemed to still be rendering HTML - maybe to do with the Accept header
    //   - I couldn't debug because the local dev proxy sets Content-Encoding: null which curl gets very upset about
    //   - Removing that line from the proxy broke local development
    //
    // So I just moved on and pulled it through an object URL
    const report = await ajax(`/apim/usage/report.csv`, {
      // ajax is a wrapper around JQuery $.ajax which assumes JSON unless you tell it otherwise
      // without this we'll get an error because it will try to parse the CSV as JSON
      dataType: 'text'
    });

    const url = URL.createObjectURL(new Blob([report]));
    const a = document.createElement('a');

    a.href = url;
    a.download = "report.csv";

    document.body.appendChild(a);

    a.click();
    a.remove();
  }
}


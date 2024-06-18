import Component from "@ember/component";

export default class ApimCredential extends Component {
  actions = {
    showApiKey() {
      this.get('showApiKey')()
    },

    createApiKey() {
      this.get('createApiKey')()
    }
  }
}
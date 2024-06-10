export default {
  resource: "group",
  path: "u/:group",
  map() {
    this.route("apim");
  }
};
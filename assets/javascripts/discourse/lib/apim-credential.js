import { tracked } from "@glimmer/tracking";

export class ApimCredential {
  @tracked apiKey;

  constructor({ product, displayName, enabled, usage }) {
    this.product = product;
    this.displayName = displayName;
    this.enabled = enabled;
    this.usage = usage;
  }

  // Usage months come back from Azure keyed as YYYY-MM.
  get callsThisMonth() {
    const now = new Date();
    const key = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

    return (this.usage ?? []).find(({ month }) => month === key)?.count ?? 0;
  }
}

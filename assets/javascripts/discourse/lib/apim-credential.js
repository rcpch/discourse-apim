import { tracked } from '@glimmer/tracking';

export class ApimCredential {
  @tracked apiKey;

  constructor({ product, displayName, enabled, usage }) {
    this.product = product;
    this.displayName = displayName;
    this.enabled = enabled;
    this.usage = usage;
  }

  callsThisMonth = () => {
    const key = moment().format('YYYY-MM');
    const usageThisMonth = (this.usage ?? []).find(({ month }) => month == key);

    return usageThisMonth?.count ?? 0;
  }
}
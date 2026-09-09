import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import loadChartJS from "discourse/lib/load-chart-js";

export default class UsageChart extends Component {
  chart;

  @action
  async renderChart(element) {
    const Chart = await loadChartJS();

    // Most recent 12 months, oldest first.
    const sorted = [...(this.args.data ?? [])]
      .sort((a, b) => b.month.localeCompare(a.month))
      .slice(0, 12)
      .reverse();

    const backgroundColor =
      getComputedStyle(document.body).getPropertyValue("--tertiary") ||
      "#ffffff";

    this.resetChart();

    this.chart = new Chart(element.getContext("2d"), {
      type: "bar",
      data: {
        labels: sorted.map(({ month }) => month),
        datasets: [
          {
            data: sorted.map(({ count }) => count),
            label: "Successful API calls",
            fill: true,
            backgroundColor,
          },
        ],
      },
      options: {
        // Chart.js handles redrawing on container resize itself.
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
          },
        },
      },
    });
  }

  @action
  resetChart() {
    this.chart?.destroy();
    this.chart = null;
  }

  <template>
    <div>
      <canvas
        class="chart-canvas"
        {{didInsert this.renderChart}}
        {{didUpdate this.renderChart @data}}
        {{willDestroy this.resetChart}}
      ></canvas>
    </div>
  </template>
}

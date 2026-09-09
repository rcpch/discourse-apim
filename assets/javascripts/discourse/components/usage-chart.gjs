import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

export default class UsageChart extends Component {
  canvas;
  chart;

  @action
  setup(element) {
    this.canvas = element;

    window.addEventListener("resize", this.resizeHandler);

    discourseDebounce(this, this.scheduleChartRendering, 100);
  }

  @action
  dataChanged() {
    discourseDebounce(this, this.scheduleChartRendering, 100);
  }

  @action
  teardown() {
    window.removeEventListener("resize", this.resizeHandler);
    this.resetChart();
  }

  @bind
  resizeHandler() {
    discourseDebounce(this, this.scheduleChartRendering, 500);
  }

  scheduleChartRendering() {
    schedule("afterRender", () => {
      this.renderChart(this.args.data, this.canvas);
    });
  }

  renderChart(model, chartCanvas) {
    if (!chartCanvas) {
      return;
    }

    const sorted = model
      .sortBy('month')
      .reverse()
      .slice(0, 12);

    const labels = sorted.map(({ month }) => month);
    const data = sorted.map(({ count }) => count);

    const backgroundColor = getComputedStyle(document.body).getPropertyValue('--tertiary') ?? '#ffffff';

    const context = chartCanvas.getContext("2d");

    const chartConfig = {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          data,
          label: 'Succesful API calls',
          fill: true,
          backgroundColor
        }]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    };

    loadScript("/javascripts/Chart.min.js").then(() => {
      this.resetChart();

      this.chart = new window.Chart(context, chartConfig);
    });
  }

  resetChart() {
    this.chart?.destroy();
    this.chart = null;
  }

  <template>
    <div>
      <canvas
        class="chart-canvas"
        {{didInsert this.setup}}
        {{didUpdate this.dataChanged @data}}
        {{willDestroy this.teardown}}
      ></canvas>
    </div>
  </template>
}

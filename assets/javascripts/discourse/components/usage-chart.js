import Component from "@ember/component";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";

export default class UsageChart extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    window.addEventListener("resize", this._resizeHandler);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    window.removeEventListener("resize", this._resizeHandler);
    this._resetChart();
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    discourseDebounce(this, this._scheduleChartRendering, 100);
  }

  @bind
  _resizeHandler() {
    discourseDebounce(this, this._scheduleChartRendering, 500);
  }

  _scheduleChartRendering() {
    schedule("afterRender", () => {
      if (!this.element) {
        return;
      }

      this._renderChart(
        this.data,
        this.element.querySelector(".chart-canvas")
      );
    });
  }

  _renderChart(model, chartCanvas) {
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
      this._resetChart();

      this._chart = new window.Chart(context, chartConfig);
    });
  }

  _resetChart() {
    this._chart?.destroy();
    this._chart = null;
  }
}
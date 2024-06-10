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
        this.model,
        this.element.querySelector(".chart-canvas")
      );
    });
  }

  _renderChart(model, chartCanvas) {
    if (!chartCanvas) {
      return;
    }

    const context = chartCanvas.getContext("2d");

    const chartConfig = {
      type: 'bar',
      data: {
        labels: ['Red', 'Blue', 'Yellow', 'Green', 'Purple', 'Orange'],
        datasets: [{
          label: '# of Votes',
          data: [12, 19, 3, 5, 2, 3],
          borderWidth: 1
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
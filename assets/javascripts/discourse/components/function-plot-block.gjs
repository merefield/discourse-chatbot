import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";
import {
  parseGraph,
  splitUndefinedSegments,
} from "../lib/function-plot-expression";

const COLORS = ["#0088cc", "#e4572e", "#32a66a", "#b279a2"];

export default class FunctionPlotBlock extends Component {
  @tracked failed = false;
  @tracked loading = true;

  renderPlot = modifier((element, [raw]) => {
    let disposed = false;
    let chart;
    let observer;
    let options;
    let previousWidth;

    const draw = () => {
      const width = Math.max(240, Math.min(element.clientWidth || 640, 1000));
      if (width === previousWidth) {
        return;
      }
      previousWidth = width;
      options.width = width;
      options.height = Math.max(240, Math.min(width * 0.65, 420));
      chart.build();
    };

    const initialize = async () => {
      try {
        const graph = parseGraph(raw);
        await loadScript(
          "/plugins/discourse-chatbot/function-plot/1.26.0/function-plot.js"
        );
        if (disposed) {
          return;
        }
        options = {
          target: element,
          title: graph.title,
          grid: true,
          xAxis: { domain: graph.xDomain },
          yAxis: { domain: graph.yDomain },
          data: [],
        };
        chart = window.functionPlot(options);
        chart.on("eval", (segments, index, isHelper) => {
          if (isHelper || !graph.functions[index]) {
            return;
          }
          const [minimum, maximum] = chart.meta.xScale.domain();
          const separated = splitUndefinedSegments(
            segments,
            graph.functions[index].evaluate,
            (maximum - minimum) / 999
          );
          segments.splice(0, segments.length, ...separated);
        });
        options.data = graph.functions.map((curve, index) => ({
          fn: ({ x }) => curve.evaluate(x),
          graphType: "polyline",
          sampler: "builtIn",
          nSamples: 1000,
          color: COLORS[index],
        }));
        draw();
        observer = new ResizeObserver(() => {
          if (!disposed) {
            draw();
          }
        });
        observer.observe(element);
      } catch {
        if (!disposed) {
          this.failed = true;
        }
      } finally {
        if (!disposed) {
          this.loading = false;
        }
      }
    };
    initialize();

    return () => {
      disposed = true;
      observer?.disconnect();
      if (chart) {
        chart.removeAllListeners();
        // Upstream retains every chart in a static cache, including detached post graphs.
        delete chart.constructor.cache[chart.id];
      }
    };
  });

  <template>
    <figure
      class="chatbot-function-plot"
      aria-label={{i18n "chatbot.function_plot.label"}}
    >
      {{#if this.loading}}
        <p class="chatbot-function-plot__status">{{i18n
            "chatbot.function_plot.loading"
          }}</p>
      {{/if}}
      {{#if this.failed}}
        <p class="chatbot-function-plot__error" role="alert">{{i18n
            "chatbot.function_plot.error"
          }}</p>
      {{/if}}
      <div
        class="chatbot-function-plot__canvas"
        {{this.renderPlot @data.raw}}
      ></div>
      <figcaption>{{i18n "chatbot.function_plot.help"}}</figcaption>
      <details class="chatbot-function-plot__definition">
        <summary>{{i18n "chatbot.function_plot.fallback"}}</summary>
        <pre>{{@data.raw}}</pre>
      </details>
    </figure>
  </template>
}

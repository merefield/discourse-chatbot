import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { modifier } from "ember-modifier";
import loadScript from "discourse/lib/load-script";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { parseGraph } from "../lib/function-plot-expression";
import {
  createCurveTrace,
  createGraphChart,
} from "../lib/function-plot-renderer";

export default class FunctionPlotBlock extends Component {
  @tracked failed = false;
  @tracked graph = null;
  @tracked loading = true;
  @tracked traceValues = [];

  renderPlot = modifier((element, [raw]) => {
    let disposed = false;
    let chart;
    let observer;
    let previousWidth;
    let trace;
    const locale = document.documentElement.lang || undefined;
    const formatter = new Intl.NumberFormat(locale, {
      maximumSignificantDigits: 6,
    });
    const scientificFormatter = new Intl.NumberFormat(locale, {
      maximumSignificantDigits: 6,
      notation: "scientific",
    });
    const formatNumber = (value) => {
      const magnitude = Math.abs(value);
      return (
        magnitude !== 0 && (magnitude < 0.0001 || magnitude >= 1000000)
          ? scientificFormatter
          : formatter
      ).format(value === 0 ? 0 : value);
    };

    const onWheel = (event) => {
      event.preventDefault();
      event.stopPropagation();
    };

    const resize = () => {
      const width = Math.max(240, Math.min(element.clientWidth || 640, 1000));
      const height = Math.max(260, Math.min(width * 0.7, 480));
      if (width !== previousWidth) {
        previousWidth = width;
        trace?.clear();
        element.style.height = `${height}px`;
        if (chart) {
          chart.options.width = width;
          chart.options.height = height;
          chart.build();
        }
      }
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
        this.graph = graph;
        chart = createGraphChart(element, graph, () => {
          if (!disposed) {
            this.failed = true;
          }
        });
        resize();
        if (graph.plotType === "function") {
          trace = createCurveTrace(chart, graph, (values) => {
            if (!disposed) {
              this.traceValues = values.map((value) =>
                value
                  ? i18n("chatbot.function_plot.trace_values", {
                      x: formatNumber(value.x),
                      y: formatNumber(value.y),
                    })
                  : null
              );
            }
          });
          element.addEventListener("pointermove", trace.move);
          element.addEventListener("pointerleave", trace.clear);
        }
        element.addEventListener("wheel", onWheel, { passive: false });
        observer = new ResizeObserver(() => {
          if (!disposed) {
            resize();
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
      element.removeEventListener("wheel", onWheel);
      if (trace) {
        element.removeEventListener("pointermove", trace.move);
        element.removeEventListener("pointerleave", trace.clear);
        trace.destroy();
      }
      observer?.disconnect();
      if (chart) {
        chart.removeAllListeners();
        // Upstream retains detached charts in a static cache.
        delete chart.constructor.cache[chart.id];
      }
    };
  });

  <template>
    <figure
      class="chatbot-function-plot"
      aria-label={{i18n "chatbot.function_plot.label"}}
    >
      {{#if this.graph.title}}
        <h4 class="chatbot-function-plot__title">{{this.graph.title}}</h4>
      {{/if}}
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
        data-plot-type={{this.graph.plotType}}
        hidden={{this.failed}}
        {{this.renderPlot @data.raw}}
      ></div>
      <ul class="chatbot-function-plot__legend">
        {{#each this.graph.series as |curve index|}}
          {{#if curve.expression}}
            <li>
              <span>{{curve.expression}}</span>
              {{#if (eq this.graph.plotType "function")}}
                <span class="chatbot-function-plot__coordinates">{{get
                    this.traceValues
                    index
                  }}</span>
              {{/if}}
            </li>
          {{/if}}
        {{/each}}
      </ul>
      <figcaption>{{i18n
          (if
            (eq this.graph.plotType "function")
            "chatbot.function_plot.help"
            "chatbot.function_plot.help_other"
          )
        }}</figcaption>
      <details class="chatbot-function-plot__definition">
        <summary>{{i18n "chatbot.function_plot.fallback"}}</summary>
        <pre>{{@data.raw}}</pre>
      </details>
    </figure>
  </template>
}

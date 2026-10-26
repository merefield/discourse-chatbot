import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import loadScript from "discourse/lib/load-script";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { parseGraph } from "../lib/function-plot-expression";
import { createGraphBoard } from "../lib/jsxgraph-renderer";

export default class FunctionPlotBlock extends Component {
  @tracked failed = false;
  @tracked graph = null;
  @tracked loading = true;

  renderPlot = modifier((element, [raw]) => {
    let disposed = false;
    let board;
    let observer;
    let previousWidth;

    const resize = () => {
      const width = Math.max(240, Math.min(element.clientWidth || 640, 1000));
      const height = Math.max(260, Math.min(width * 0.7, 480));
      if (width !== previousWidth) {
        previousWidth = width;
        element.style.height = `${height}px`;
        board?.resizeContainer(width, height, true);
      }
    };

    const initialize = async () => {
      try {
        const graph = parseGraph(raw);
        await loadScript(
          "/plugins/discourse-chatbot/jsxgraph/1.14.1/jsxgraphcore.js"
        );
        if (disposed) {
          return;
        }
        this.graph = graph;
        resize();
        board = createGraphBoard(element, graph);
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
      observer?.disconnect();
      if (board) {
        window.JXG.JSXGraph.freeBoard(board);
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
        {{this.renderPlot @data.raw}}
      ></div>
      <ul class="chatbot-function-plot__legend">
        {{#each this.graph.functions as |curve|}}
          <li>{{curve.expression}}</li>
        {{/each}}
      </ul>
      <figcaption>{{i18n
          (if
            (eq this.graph.dimensions 3)
            "chatbot.function_plot.help_3d"
            "chatbot.function_plot.help"
          )
        }}</figcaption>
      <details class="chatbot-function-plot__definition">
        <summary>{{i18n "chatbot.function_plot.fallback"}}</summary>
        <pre>{{@data.raw}}</pre>
      </details>
    </figure>
  </template>
}

import {
  compileExpression,
  splitUndefinedSegments,
} from "./function-plot-expression";
import { traceSeriesCoordinates } from "./function-plot-trace";

const COLORS = ["#0088cc", "#e4572e", "#32a66a", "#b279a2"];

export function compileIntervalExpression(expression, interval) {
  const monotonic = (fn) => (value) =>
    interval.isEmpty(value)
      ? interval.EMPTY
      : interval.factory(fn(value.lo), fn(value.hi));
  return compileExpression(expression, {
    variables: ["x", "y"],
    arithmetic: {
      literal: (value) => interval.factory(value),
      negative: interval.negative,
      functions: {
        ...interval,
        cbrt: monotonic(Math.cbrt),
        floor: monotonic(Math.floor),
        ceil: monotonic(Math.ceil),
      },
      operators: {
        "+": interval.add,
        "-": interval.sub,
        "*": interval.mul,
        "/": interval.div,
        "^": (base, exponent) => {
          if (interval.isSingleton(exponent) && Number.isInteger(exponent.lo)) {
            return interval.pow(base, exponent);
          }
          if (base.lo < 0) {
            return interval.WHOLE;
          }
          return interval.exp(interval.mul(interval.log(base), exponent));
        },
      },
    },
  });
}

export function createGraphChart(element, graph, onError) {
  const library = window.functionPlot;
  const options = {
    target: element,
    width: 640,
    height: 420,
    grid: true,
    xAxis: { domain: graph.xDomain },
    yAxis: { domain: graph.yDomain },
    tip: { renderer: () => "" },
    data: [],
  };
  const chart = library(options);
  let evaluations = 0;
  chart.on("before:draw", () => (evaluations = 0));
  chart.on("eval", (segments, index, isHelper) => {
    if (isHelper || graph.plotType === "implicit") {
      return;
    }
    const [minimum, maximum] = chart.meta.xScale.domain();
    const separated =
      graph.plotType === "function"
        ? splitUndefinedSegments(
            segments,
            graph.series[index].evaluate,
            (maximum - minimum) / 999
          )
        : splitUndefinedSegments(segments);
    segments.splice(0, segments.length, ...separated);
  });
  options.data = graph.series.map((series, index) => {
    const datum = {
      color: COLORS[index % COLORS.length],
      sampler: "builtIn",
      graphType: "polyline",
      nSamples: 1000,
      skipTip: true,
    };
    switch (graph.plotType) {
      case "implicit": {
        const evaluate = compileIntervalExpression(
          series.expression,
          library.intervalMath
        );
        return {
          ...datum,
          fnType: "implicit",
          sampler: "interval",
          graphType: "interval",
          fn: ({ x, y }) => {
            if (++evaluations > 40000) {
              throw new Error("Implicit plot exceeded the evaluation budget");
            }
            return evaluate(x, y);
          },
        };
      }
      case "parametric":
        return {
          ...datum,
          fnType: "parametric",
          x: ({ t }) => series.evaluateX(t),
          y: ({ t }) => series.evaluateY(t),
          range: graph.parameterRange,
        };
      case "polar":
        return {
          ...datum,
          fnType: "polar",
          r: ({ theta }) => series.evaluate(theta),
          range: graph.parameterRange,
        };
      case "points":
      case "polyline":
        return {
          ...datum,
          fnType: "points",
          points: series.points,
          graphType: graph.plotType === "points" ? "scatter" : "polyline",
        };
      case "vector":
        return {
          ...datum,
          fnType: "vector",
          offset: series.vector.slice(0, 2),
          vector: series.vector.slice(2),
        };
      default:
        return {
          ...datum,
          fnType: "linear",
          fn: ({ x }) => series.evaluate(x),
        };
    }
  });

  // Zoom redraws happen inside the library's event handlers, outside the component's initializer.
  const draw = chart.draw.bind(chart);
  chart.draw = () => {
    try {
      draw();
    } catch {
      options.data = [];
      onError();
    }
  };
  chart.build();
  return chart;
}

export function createCurveTrace(chart, graph, onValues) {
  const canvas = chart.canvas.merge(chart.canvas.enter);
  const overlay = canvas.append("g").attr("pointer-events", "none");
  const points = graph.series.map((_series, index) =>
    overlay
      .append("circle")
      .attr("class", "chatbot-function-plot__trace-point")
      .attr("r", 4)
      .attr("fill", COLORS[index])
      .attr("display", "none")
  );
  let frame;
  let pointer;
  const clear = () => {
    cancelAnimationFrame(frame);
    frame = null;
    points.forEach((point) => point.attr("display", "none"));
    onValues([]);
  };
  const update = () => {
    frame = null;
    const box = chart.draggable.node().getBoundingClientRect();
    const pixelX = pointer.clientX - box.left;
    const pixelY = pointer.clientY - box.top;
    if (pixelX < 0 || pixelX > box.width || pixelY < 0 || pixelY > box.height) {
      clear();
      return;
    }
    const [minX, maxX] = chart.meta.xScale.domain();
    const [minY, maxY] = chart.meta.yScale.domain();
    const values = traceSeriesCoordinates(
      graph.series.map((series) => series.evaluate),
      chart.meta.xScale.invert(pixelX),
      [minX, maxY, maxX, minY],
      box.width
    );
    points.forEach((point, index) => {
      const value = values[index];
      point.attr("display", value ? null : "none");
      if (value) {
        point
          .attr("cx", chart.meta.xScale(value.x))
          .attr("cy", chart.meta.yScale(value.y));
      }
    });
    onValues(values);
  };
  chart.on("before:draw", clear);
  return {
    move(event) {
      pointer = { clientX: event.clientX, clientY: event.clientY };
      frame ??= requestAnimationFrame(update);
    },
    clear,
    destroy() {
      clear();
      chart.removeListener("before:draw", clear);
      overlay.remove();
    },
  };
}

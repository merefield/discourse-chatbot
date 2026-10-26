const COLORS = ["#0088cc", "#e4572e", "#32a66a", "#b279a2"];

export function createGraphBoard(element, graph) {
  const library = window.JXG;
  // Internal labels must also use the interpreter under Discourse's CSP.
  library.Options.jc.compile = false;
  const is3D = graph.dimensions === 3;
  const primary = getComputedStyle(element)
    .getPropertyValue("--primary")
    .trim();
  const axis = {
    strokeColor: primary,
    ticks: {
      label: { strokeColor: primary, display: "internal", parse: false },
    },
  };
  element.id ||= `chatbot-plot-${crypto.randomUUID()}`;
  element.dataset.dimensions = graph.dimensions;
  const board = library.JSXGraph.initBoard(element, {
    renderer: "svg",
    boundingbox: is3D
      ? [-8, 6, 8, -6]
      : [
          graph.xDomain[0],
          graph.yDomain[1],
          graph.xDomain[1],
          graph.yDomain[0],
        ],
    axis: !is3D,
    defaultAxes: { x: axis, y: axis },
    grid: !is3D,
    showCopyright: false,
    showNavigation: false,
    showInfobox: false,
    keepaspectratio: is3D,
    resize: { enabled: false },
    // The component handles wheel events to prevent zoom from also scrolling the page.
    registerEvents: { wheel: false },
    pan: { enabled: !is3D, needShift: false },
    zoom: { enabled: true, needShift: false },
    title: "",
    description: "",
  });
  board.options.text.display = "internal";
  board.options.text.parse = false;
  board.options.text.useMathJax = false;
  const curves = [];
  board.suspendUpdate();
  try {
    if (is3D) {
      const view = board.create(
        "view3d",
        [
          [-6, -4],
          [12, 8],
          [graph.xDomain, graph.yDomain, graph.zDomain],
        ],
        {
          projection: "parallel",
          trackball: { enabled: true },
          axesPosition: "center",
          depthOrder: { enabled: true },
          xPlaneRear: { visible: false },
          yPlaneRear: { visible: false },
          zPlaneRear: { visible: false },
        }
      );
      graph.functions.forEach((curve, index) => {
        view.create(
          "functiongraph3d",
          [curve.evaluate, graph.xDomain, graph.yDomain],
          {
            type: "shader",
            tiling: "triangle",
            stepsU: 24,
            stepsV: 24,
            polyhedron: {
              visible: true,
              strokeWidth: 0,
              fillOpacity: 0.85,
              shader: {
                enabled: true,
                hue: index === 0 ? 200 : 15,
                saturation: 80,
                minLightness: 35,
                maxLightness: 75,
              },
            },
          }
        );
      });
    } else {
      graph.functions.forEach((curve, index) => {
        curves.push(
          board.create("functiongraph", [curve.evaluate], {
            strokeColor: COLORS[index],
            strokeWidth: 2,
            highlight: false,
            doAdvancedPlot: true,
            recursionDepthHigh: 12,
            recursionDepthLow: 8,
          })
        );
      });
    }
    board.unsuspendUpdate();
    curves.forEach((curve, index) => {
      curve.rendNode.classList.add("chatbot-function-plot__curve");
      curve.rendNode.dataset.curve = index;
    });
    return board;
  } catch (error) {
    library.JSXGraph.freeBoard(board);
    throw error;
  }
}

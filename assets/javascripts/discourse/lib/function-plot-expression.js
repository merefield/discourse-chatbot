const FUNCTIONS = Object.freeze({
  sin: Math.sin,
  cos: Math.cos,
  tan: Math.tan,
  asin: Math.asin,
  acos: Math.acos,
  atan: Math.atan,
  sqrt: Math.sqrt,
  cbrt: Math.cbrt,
  abs: Math.abs,
  exp: Math.exp,
  log: Math.log,
  log10: Math.log10,
  floor: Math.floor,
  ceil: Math.ceil,
});
const PRECEDENCE = { "+": 1, "-": 1, "*": 2, "/": 2, "^": 4 };
const OPERATORS = {
  "+": (left, right) => left + right,
  "-": (left, right) => left - right,
  "*": (left, right) => left * right,
  "/": (left, right) => left / right,
  "^": (left, right) => Math.pow(left, right),
};

// Interpret a small maths grammar; never pass post text to the library's code generator.
export function compileExpression(
  expression,
  { variables = ["x"], arithmetic } = {}
) {
  const functions = arithmetic?.functions ?? FUNCTIONS;
  const operators = arithmetic?.operators ?? OPERATORS;
  const literal = arithmetic?.literal ?? ((value) => value);
  if (
    typeof expression !== "string" ||
    !expression.trim() ||
    expression.length > 256
  ) {
    throw new Error("Invalid expression");
  }
  const source = expression.trim().toLowerCase();
  const pattern =
    /(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?|[a-z][a-z0-9]*|[()+\-*/^]/y;
  const tokens = [];
  let offset = 0;
  while (offset < source.length) {
    if (/\s/.test(source[offset])) {
      offset++;
      continue;
    }
    pattern.lastIndex = offset;
    const match = pattern.exec(source);
    if (!match || tokens.length >= 128) {
      throw new Error("Invalid expression");
    }
    tokens.push(match[0]);
    offset = pattern.lastIndex;
  }

  let index = 0;
  function parse(minimum = 1, depth = 0) {
    if (depth > 32) {
      throw new Error("Expression too complex");
    }
    const token = tokens[index++];
    let left;
    if (token === "+" || token === "-") {
      const operand = parse(3, depth + 1);
      left =
        token === "-"
          ? (x, y) =>
              arithmetic ? arithmetic.negative(operand(x, y)) : -operand(x, y)
          : operand;
    } else if (token === "(") {
      left = parse(1, depth + 1);
      if (tokens[index++] !== ")") {
        throw new Error("Unclosed group");
      }
    } else if (variables.includes(token)) {
      left = variables.indexOf(token) === 0 ? (x) => x : (_x, y) => y;
    } else if (token === "pi" || token === "e") {
      const constant = literal(token === "pi" ? Math.PI : Math.E);
      left = () => constant;
    } else if (Object.hasOwn(FUNCTIONS, token)) {
      if (tokens[index++] !== "(") {
        throw new Error("Missing function argument");
      }
      const argument = parse(1, depth + 1);
      if (tokens[index++] !== ")") {
        throw new Error("Invalid function argument");
      }
      left = (x, y) => functions[token](argument(x, y));
    } else if (token && Number.isFinite(Number(token))) {
      const number = literal(Number(token));
      left = () => number;
    } else {
      throw new Error("Unsupported expression");
    }

    while (
      Object.hasOwn(PRECEDENCE, tokens[index]) &&
      PRECEDENCE[tokens[index]] >= minimum
    ) {
      const operator = tokens[index++];
      const right = parse(
        PRECEDENCE[operator] + (operator === "^" ? 0 : 1),
        depth + 1
      );
      const previous = left;
      left = (x, y) => operators[operator](previous(x, y), right(x, y));
    }
    return left;
  }

  const evaluate = parse();
  if (index !== tokens.length) {
    throw new Error("Unexpected expression input");
  }
  return (x, y) => {
    const result = evaluate(x, y);
    return arithmetic ? result : Number.isFinite(result) ? result : NaN;
  };
}

function domain(value) {
  if (
    !Array.isArray(value) ||
    value.length !== 2 ||
    !value.every(
      (bound) =>
        typeof bound === "number" &&
        Number.isFinite(bound) &&
        Math.abs(bound) <= 1000000
    ) ||
    value[1] - value[0] < 0.000001
  ) {
    throw new Error("Invalid graph bounds");
  }
  return [...value];
}

const PLOT_TYPES = [
  "function",
  "implicit",
  "parametric",
  "polar",
  "points",
  "polyline",
  "vector",
];

function tuples(value, size, limit) {
  if (
    !Array.isArray(value) ||
    !value.length ||
    value.length > limit ||
    value.some(
      (tuple) =>
        !Array.isArray(tuple) ||
        tuple.length !== size ||
        tuple.some(
          (number) =>
            typeof number !== "number" ||
            !Number.isFinite(number) ||
            Math.abs(number) > 1000000
        )
    )
  ) {
    throw new Error("Invalid graph data");
  }
  return value;
}

export function parseGraph(raw) {
  if (typeof raw !== "string" || raw.length > 8192) {
    throw new Error("Graph too large");
  }
  const graph = JSON.parse(raw);
  const plotType = graph?.plot_type ?? "function";
  const dataKey =
    plotType === "vector"
      ? "vectors"
      : ["points", "polyline"].includes(plotType)
        ? "points"
        : "functions";
  const parameterized = ["parametric", "polar"].includes(plotType);
  const allowedKeys = [
    dataKey,
    "plot_type",
    "title",
    "x_domain",
    "y_domain",
    "dimensions",
  ];
  if (parameterized) {
    allowedKeys.push("parameter_range");
  }
  if (
    !graph ||
    !PLOT_TYPES.includes(plotType) ||
    (graph.dimensions !== undefined && graph.dimensions !== 2) ||
    Object.keys(graph).some((key) => !allowedKeys.includes(key))
  ) {
    throw new Error("Invalid graph");
  }
  const title = graph.title ?? "";
  if (typeof title !== "string" || title.length > 120 || /[\r\n]/.test(title)) {
    throw new Error("Invalid title");
  }
  const result = {
    plotType,
    title,
    xDomain: domain(graph.x_domain ?? [-10, 10]),
    yDomain: domain(graph.y_domain ?? [-10, 10]),
    parameterRange: parameterized
      ? domain(graph.parameter_range ?? [0, 2 * Math.PI])
      : null,
    series: [],
  };
  if (dataKey !== "functions") {
    const data = tuples(
      graph[dataKey],
      plotType === "vector" ? 4 : 2,
      plotType === "vector" ? 16 : 150
    );
    result.series =
      plotType === "vector"
        ? data.map((vector) => ({ expression: vector.join(", "), vector }))
        : [{ expression: "", points: data }];
    return result;
  }
  if (
    !Array.isArray(graph.functions) ||
    !graph.functions.length ||
    graph.functions.length > (plotType === "implicit" ? 2 : 4)
  ) {
    throw new Error("Invalid graph functions");
  }
  result.series = graph.functions.map((expression) => {
    if (plotType === "parametric") {
      if (!Array.isArray(expression) || expression.length !== 2) {
        throw new Error("Invalid parametric pair");
      }
      return {
        expression: expression.join("; "),
        evaluateX: compileExpression(expression[0], { variables: ["t"] }),
        evaluateY: compileExpression(expression[1], { variables: ["t"] }),
      };
    }
    const variables =
      plotType === "implicit"
        ? ["x", "y"]
        : plotType === "polar"
          ? ["theta"]
          : ["x"];
    return {
      expression,
      evaluate: compileExpression(expression, { variables }),
    };
  });
  return result;
}

// The upstream sampler drops undefined points, which can otherwise bridge domain gaps.
export function splitUndefinedSegments(
  segments,
  evaluate = () => 0,
  step = Infinity
) {
  const result = [];
  for (const segment of segments) {
    let current = [];
    for (const point of segment) {
      if (!point || !point.every(Number.isFinite)) {
        if (current.length) {
          result.push(current);
          current = [];
        }
        continue;
      }
      const previous = current.at(-1);
      if (
        previous &&
        (point[0] - previous[0] > step * 1.5 ||
          !Number.isFinite(evaluate((point[0] + previous[0]) / 2)))
      ) {
        result.push(current);
        current = [];
      }
      current.push(point);
    }
    if (current.length) {
      result.push(current);
    }
  }
  return result;
}

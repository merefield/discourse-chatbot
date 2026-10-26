import { module, test } from "qunit";
import {
  compileExpression,
  parseGraph,
  splitUndefinedSegments,
} from "discourse/plugins/discourse-chatbot/discourse/lib/function-plot-expression";

module("Chatbot | function plot expressions", function () {
  test("interprets curve expressions with mathematical operator precedence", function (assert) {
    [
      ["x^2-4", 3, 5],
      ["-x^2", 3, -9],
      ["2^-x", 3, 0.125],
      ["2^3^2", 0, 512],
      ["sin(pi/2)+cos(0)", 0, 2],
      ["exp(log(e))", 0, Math.E],
      ["log10(1000)", 0, 3],
      ["sqrt(abs(x))", -4, 2],
      ["1e3*x", 2, 2000],
    ].forEach(([expression, x, expected]) => {
      assert.true(
        Math.abs(compileExpression(expression)(x) - expected) < 1e-10,
        expression
      );
    });
    assert.true(Number.isNaN(compileExpression("1/x")(0)), "pole is a gap");
    assert.true(
      Number.isNaN(compileExpression("sqrt(x)")(-1)),
      "undefined domain is a gap"
    );
  });

  test("rejects code, property access, unknown symbols and excessive complexity", function (assert) {
    [
      "window.alert(1)",
      "constructor(x)",
      "x=1",
      "x;alert(1)",
      "x[0]",
      "sin(",
      "sin(x,2)",
      "x y",
      "",
      "x".repeat(257),
      "(".repeat(40) + "x" + ")".repeat(40),
    ].forEach((expression) => {
      assert.throws(() => compileExpression(expression), undefined, expression);
    });
  });

  test("accepts bounded graph definitions and rejects arbitrary library options", function (assert) {
    const graph = parseGraph(
      JSON.stringify({
        functions: ["sin(x)", "cos(x)"],
        x_domain: [-7, 7],
        y_domain: [-2, 2],
        title: "Two curves",
      })
    );
    assert.strictEqual(graph.functions.length, 2);
    assert.deepEqual(graph.xDomain, [-7, 7]);
    assert.deepEqual(graph.yDomain, [-2, 2]);
    assert.strictEqual(graph.functions[0].evaluate(0), 0);
    [
      { functions: [] },
      { functions: ["x", "x", "x", "x", "x"] },
      { functions: ["x"], target: "body" },
      { functions: ["x"], title: "a".repeat(121) },
      { functions: ["x"], x_domain: [0, 0] },
      { functions: ["x"], x_domain: [-1e7, 1e7] },
      { functions: ["x"], y_domain: [10, -10] },
    ].forEach((value) =>
      assert.throws(() => parseGraph(JSON.stringify(value)))
    );
    assert.throws(() => parseGraph("x".repeat(8193)));
  });

  test("keeps sampled curves separate across undefined domains", function (assert) {
    const evaluate = compileExpression("sqrt(x^2-1)");
    const points = [-2, -1.5, -1, 1, 1.5, 2].map((x) => [x, evaluate(x)]);
    assert.deepEqual(splitUndefinedSegments([points], evaluate, 0.5), [
      points.slice(0, 3),
      points.slice(3),
    ]);
    assert.deepEqual(splitUndefinedSegments([[undefined]], evaluate, 0.5), []);
    assert.deepEqual(
      splitUndefinedSegments(
        [
          [
            [0, 0],
            [1, 1],
          ],
        ],
        compileExpression("x"),
        1
      ),
      [
        [
          [0, 0],
          [1, 1],
        ],
      ]
    );
  });
});

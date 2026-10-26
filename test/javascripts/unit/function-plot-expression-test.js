import { module, test } from "qunit";
import {
  compileExpression,
  parseGraph,
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
      ["cbrt(x)", -8, -2],
      ["cbrt((3-4*x^3)/2)", 1, Math.cbrt(-0.5)],
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

  test("supports two independent variables only for 3D surfaces", function (assert) {
    const graph = parseGraph(
      JSON.stringify({
        dimensions: 3,
        functions: ["sin(x)*cos(y)", "x^2-y^2"],
        z_domain: [-2, 2],
      })
    );
    assert.strictEqual(graph.dimensions, 3);
    assert.deepEqual(graph.zDomain, [-2, 2]);
    assert.strictEqual(graph.functions[0].evaluate(Math.PI / 2, 0), 1);
    assert.strictEqual(graph.functions[1].evaluate(3, 2), 5);
    assert.throws(() => compileExpression("y"));
    [
      { functions: ["y"] },
      { functions: ["x"], dimensions: 4 },
      { functions: ["x"], z_domain: [-1, 1] },
      { functions: ["x"], dimensions: 3, z_domain: [2, 1] },
      { functions: ["x", "y", "x+y"], dimensions: 3 },
    ].forEach((value) =>
      assert.throws(() => parseGraph(JSON.stringify(value)))
    );
  });
});

import { module, test } from "qunit";
import loadScript from "discourse/lib/load-script";
import { splitUndefinedSegments } from "discourse/plugins/discourse-chatbot/discourse/lib/function-plot-expression";
import { compileIntervalExpression } from "discourse/plugins/discourse-chatbot/discourse/lib/function-plot-renderer";

module("Chatbot | function plot renderer", function () {
  test("evaluates implicit expressions with conservative intervals without code generation", async function (assert) {
    await loadScript(
      "/plugins/discourse-chatbot/function-plot/1.26.0/function-plot.js"
    );
    const interval = window.functionPlot.intervalMath;
    const factory = interval.factory;
    const cases = [
      ["x^2+y^2-4", factory(-1, 1), factory(1, 2), [-3, 1]],
      ["sin(x)+cos(y)", factory(0, Math.PI / 2), factory(0), [1, 2]],
      ["cbrt(x)-y", factory(-8, 8), factory(0), [-2, 2]],
      ["floor(x)+ceil(y)", factory(1.1, 1.9), factory(1.1, 1.9), [3, 3]],
      ["x^0.5", factory(1, 4), factory(0), [1, 2]],
      ["x^y", factory(-2, 2), factory(1, 2), [-4, 4]],
      ["log10(x)", factory(1, 100), factory(0), [0, 2]],
    ];
    for (const [expression, x, y, expected] of cases) {
      const actual = compileIntervalExpression(expression, interval)(x, y);
      assert.true(
        actual.lo <= expected[0] + 1e-12,
        `${expression}: lower bound`
      );
      assert.true(
        actual.hi >= expected[1] - 1e-12,
        `${expression}: upper bound`
      );
    }
    assert.throws(() => compileIntervalExpression("window.alert(1)", interval));
  });

  test("keeps undefined curve domains and trajectory samples as separate segments", function (assert) {
    assert.deepEqual(
      splitUndefinedSegments(
        [
          [
            [0, 2],
            [1, 1],
            [3, 1],
            [4, 2],
          ],
        ],
        (x) => Math.sqrt((x - 1) * (x - 3)),
        1
      ),
      [
        [
          [0, 2],
          [1, 1],
        ],
        [
          [3, 1],
          [4, 2],
        ],
      ]
    );
    assert.deepEqual(
      splitUndefinedSegments([
        [
          [0, 0],
          [NaN, 1],
          [2, 2],
        ],
      ]),
      [[[0, 0]], [[2, 2]]]
    );
    assert.deepEqual(splitUndefinedSegments([[undefined]]), []);
  });
});

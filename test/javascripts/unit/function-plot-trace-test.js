import { module, test } from "qunit";
import {
  traceCoordinates,
  traceSeriesCoordinates,
} from "discourse/plugins/discourse-chatbot/discourse/lib/function-plot-trace";

module("Chatbot | curve tracing", function () {
  test("snaps intersecting series to a shared point", function (assert) {
    const values = traceSeriesCoordinates(
      [(x) => x + 1, (x) => 3 - x],
      1.03,
      [-5, 5, 5, -5],
      500
    );
    assert.true(Math.abs(values[0].x - 1) < 1e-10);
    assert.strictEqual(values[0].y, 2);
    assert.deepEqual(values[0], values[1]);
  });
  test("chooses the closest of nearby series crossings", function (assert) {
    const values = traceSeriesCoordinates(
      [(x) => x + 1, (x) => 3 - x, (x) => 4.2 - 2 * x],
      1.04,
      [-5, 5, 5, -5],
      500
    );
    assert.true(Math.abs(values[0].x - 3.2 / 3) < 1e-10);
    assert.deepEqual(values[0], values[2]);
  });
  test("ignores coincident series, poles and offscreen intersections", function (assert) {
    const overlap = traceSeriesCoordinates(
      [() => 2, () => 2],
      1.03,
      [-5, 5, 5, -5],
      500
    );
    assert.deepEqual(overlap, [
      { x: 1.03, y: 2 },
      { x: 1.03, y: 2 },
    ]);
    const pole = traceSeriesCoordinates(
      [(x) => 1 / (x - 1), () => 0],
      1.02,
      [-5, 100, 5, -100],
      500
    );
    assert.strictEqual(pole[0].x, 1.02);
    assert.true(Math.abs(pole[0].y - 50) < 1e-8);
    assert.deepEqual(
      traceSeriesCoordinates(
        [(x) => x + 100, (x) => 102 - x],
        1.03,
        [-5, 5, 5, -5],
        500
      ),
      [null, null]
    );
  });
  test("snaps to a visible y-axis intercept within six pixels", function (assert) {
    assert.deepEqual(
      traceCoordinates((x) => x * x + 2, 0.02, [-5, 5, 5, -5], 500),
      { x: 0, y: 2 }
    );
    assert.deepEqual(
      traceCoordinates((x) => x * x + 2, 0.2, [-5, 5, 5, -5], 500),
      { x: 0.2, y: 2.04 }
    );
  });
  test("snaps to nearby zeros including cubic roots with steep slopes", function (assert) {
    const quadratic = traceCoordinates(
      (x) => x * x - 4,
      2.03,
      [-5, 5, 5, -5],
      500
    );
    assert.true(Math.abs(quadratic.x - 2) < 1e-10);
    assert.strictEqual(quadratic.y, 0);
    const cubic = traceCoordinates(
      (x) => Math.cbrt((3 - 4 * x * x * x) / 2),
      0.92,
      [-2, 5, 2, -5],
      500
    );
    assert.true(Math.abs(cubic.x - Math.cbrt(0.75)) < 1e-10);
    assert.strictEqual(cubic.y, 0);
  });
  test("keeps poles, jumps and undefined values from becoming false intercepts", function (assert) {
    const pole = traceCoordinates((x) => 1 / x, 0.02, [-1, 100, 1, -100], 500);
    assert.deepEqual(pole, { x: 0.02, y: 50 });
    const jump = traceCoordinates(
      (x) => Math.floor(x) * 2 + 1,
      0.02,
      [-1, 5, 1, -5],
      500
    );
    assert.deepEqual(jump, { x: 0, y: 1 });
    assert.strictEqual(
      traceCoordinates((x) => Math.sqrt(x), -1, [-2, 5, 2, -5], 500),
      null
    );
    assert.strictEqual(
      traceCoordinates((x) => x * x + 10, 1, [-2, 5, 2, -5], 500),
      null
    );
  });
});

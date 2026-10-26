function crossing(evaluate, left, right) {
  let leftValue = evaluate(left);
  let rightValue = evaluate(right);
  if (!Number.isFinite(leftValue) || !Number.isFinite(rightValue)) {
    return null;
  }
  if (leftValue === 0 && rightValue === 0) {
    return null;
  }
  if (leftValue === 0) {
    return left;
  }
  if (rightValue === 0) {
    return right;
  }
  if (Math.sign(leftValue) === Math.sign(rightValue)) {
    return null;
  }
  const initialLeft = Math.abs(leftValue);
  const initialRight = Math.abs(rightValue);
  for (let iteration = 0; iteration < 48; iteration++) {
    const middle = left + (right - left) / 2;
    if (middle === left || middle === right) {
      break;
    }
    const value = evaluate(middle);
    if (!Number.isFinite(value)) {
      return null;
    }
    if (value === 0) {
      return middle;
    }
    if (Math.sign(value) === Math.sign(leftValue)) {
      left = middle;
      leftValue = value;
    } else {
      right = middle;
      rightValue = value;
    }
  }
  // Both sides must approach zero: sign changes alone also occur at poles and jumps.
  if (
    Math.abs(leftValue) < initialLeft * 0.001 &&
    Math.abs(rightValue) < initialRight * 0.001
  ) {
    return left + (right - left) / 2;
  }
  return null;
}

export function traceSeriesCoordinates(evaluators, x, bounds, width) {
  const [minimumX, maximumY, maximumX, minimumY] = bounds;
  const tolerance = ((maximumX - minimumX) * 6) / width;
  const candidates = [];
  const samples = [
    Math.max(minimumX, x - tolerance),
    x,
    Math.min(maximumX, x + tolerance),
  ];
  const roots = (evaluate) => {
    const result = [];
    for (let index = 1; index < samples.length; index++) {
      const root = crossing(evaluate, samples[index - 1], samples[index]);
      if (root !== null) {
        result.push(root);
      }
    }
    return result;
  };
  const visible = (value) =>
    Number.isFinite(value.x) &&
    Number.isFinite(value.y) &&
    value.y >= minimumY &&
    value.y <= maximumY;
  evaluators.forEach((evaluate, index) => {
    if (minimumX <= 0 && maximumX >= 0 && Math.abs(x) <= tolerance) {
      candidates.push({ x: 0, y: evaluate(0), indices: [index] });
    }
    if (minimumY <= 0 && maximumY >= 0) {
      roots(evaluate).forEach((root) =>
        candidates.push({ x: root, y: 0, indices: [index] })
      );
    }
    for (let other = index + 1; other < evaluators.length; other++) {
      roots((value) => evaluate(value) - evaluators[other](value)).forEach(
        (root) => {
          const firstY = evaluate(root);
          const secondY = evaluators[other](root);
          if (
            visible({ x: root, y: firstY }) &&
            visible({ x: root, y: secondY })
          ) {
            candidates.push({
              x: root,
              y: firstY + (secondY - firstY) / 2,
              indices: [index, other],
            });
          }
        }
      );
    }
  });
  const snapped = candidates
    .filter(visible)
    .sort(
      (first, second) =>
        Math.abs(first.x - x) - Math.abs(second.x - x) ||
        second.indices.length - first.indices.length
    )[0];
  const traceX = snapped?.x ?? x;
  return evaluators.map((evaluate, index) => {
    const value = {
      x: traceX,
      y: snapped?.indices.includes(index) ? snapped.y : evaluate(traceX),
    };
    return visible(value) ? value : null;
  });
}

export function traceCoordinates(evaluate, x, bounds, width) {
  return traceSeriesCoordinates([evaluate], x, bounds, width)[0];
}

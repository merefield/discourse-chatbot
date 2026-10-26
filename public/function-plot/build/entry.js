import functionPlot from "function-plot";
import { Interval } from "interval-arithmetic-eval";

// Expose the interval arithmetic already used by the sampler for trusted callbacks.
functionPlot.intervalMath = Interval;
window.functionPlot = functionPlot;

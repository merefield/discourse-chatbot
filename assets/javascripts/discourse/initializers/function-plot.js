import { apiInitializer } from "discourse/lib/api";
import FunctionPlotBlock from "../components/function-plot-block";

export function decorateFunctionPlots(element, helper) {
  element.querySelectorAll("pre > code.lang-function-plot").forEach((code) => {
    const raw = code.textContent;
    const container = document.createElement("div");
    container.className = "chatbot-function-plot-container";
    code.parentElement.replaceWith(container);
    helper.renderGlimmer(container, FunctionPlotBlock, { raw });
  });
}

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");
  if (!settings.chatbot_enabled || !settings.chatbot_function_plot_enabled) {
    return;
  }
  api.decorateCookedElement(decorateFunctionPlots, {
    id: "chatbot-function-plot",
  });
  api.decorateChatMessage?.(decorateFunctionPlots);
});

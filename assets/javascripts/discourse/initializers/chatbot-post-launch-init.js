import { hbs } from "ember-cli-htmlbars";
import { apiInitializer } from "discourse/lib/api";
import RenderGlimmer from "discourse/widgets/render-glimmer";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  api.decorateWidget("post-date:after", (helper) => {
    if (!siteSettings.chatbot_quick_access_bot_post_kicks_off) {
      return;
    }

    const post = helper.getModel();

    if (!post) {
      return;
    }

    return new RenderGlimmer(
      helper.widget,
      "div.chatbot-post-launcher",
      hbs`<ChatbotLaunch @post={{@data.post}} />`,
      {
        post,
      }
    );
  });
});

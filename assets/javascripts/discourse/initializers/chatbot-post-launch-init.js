import { apiInitializer } from "discourse/lib/api";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { hbs } from "ember-cli-htmlbars";

export default apiInitializer("1.8.0", (api) => {

  api.decorateWidget("post-date:after", (helper) => {
    if (!SiteSetting.chatbot_quick_access_bot_post_kicks_off) return;

    const post = helper.getModel();

    if (!post) return;

    return new RenderGlimmer(
      helper.widget,
      "div.chatbot-post-launcher",
      hbs`<ChatbotLaunch @post={{@data.post}} />`,
      {
        post: post
      }
    );
  });
});

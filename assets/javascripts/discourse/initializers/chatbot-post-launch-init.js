import { hbs } from "ember-cli-htmlbars";
import { apiInitializer } from "discourse/lib/api";
import RenderGlimmer from "discourse/widgets/render-glimmer";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  api.modifyClass("component:chat-channel", {
    async fetchMessages(findArgs = {}) {
      if (this.messagesLoader.loading) {
        return;
      }

      this.messagesManager.clear();

      const result = await this.messagesLoader.load(findArgs);
      this.messagesManager.messages = this.processMessages(
        this.args.channel,
        result
      );
      if (findArgs.target_message_id) {
        this.scrollToMessageId(findArgs.target_message_id, {
          highlight: true,
          position: findArgs.position,
        });
      } else if (findArgs.fetch_from_last_read) {
        const lastReadMessageId = this.currentUserMembership?.lastReadMessageId;
        if (this.args.channel.chatable.type === "DirectMessage") {
          this.scrollToBottom();
        } else {
          this.scrollToMessageId(lastReadMessageId);
        }
      } else if (findArgs.target_date) {
        this.scrollToMessageId(result.meta.target_message_id, {
          highlight: true,
          position: "center",
        });
      } else {
        this._ignoreNextScroll = true;
        this.scrollToBottom();
      }

      this.debounceFillPaneAttempt();
      this.debouncedUpdateLastReadMessage();
    },
  });

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

import { apiInitializer } from "discourse/lib/api";
import ChatbotLaunch from "../components/chatbot-launch";

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  api.modifyClass("component:chat-channel", {
    pluginId: "discourse-chatbot",
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
        if (
          this.args.channel.chatable.type === "DirectMessage" &&
          this.args.channel.unicodeTitle === this.siteSettings.chatbot_bot_user
        ) {
          this.scrollToMessageId(
            this.messagesManager.messages[
              this.messagesManager.messages.length - 1
            ].id
          );
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

  if (siteSettings.chatbot_quick_access_bot_post_kicks_off) {
    api.registerValueTransformer(
      "post-menu-buttons",
      ({ value: dag, context: { firstButtonKey } }) => {
        dag.add("chatbot-post-launch-button", ChatbotLaunch, {
          before: firstButtonKey,
        });
      }
    );
  }
});

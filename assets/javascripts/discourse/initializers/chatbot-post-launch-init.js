import { apiInitializer } from "discourse/lib/api";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";
import ChatbotLaunch from "../components/chatbot-launch";

const CHATBOT_FETCH_MESSAGES_PATCHED = Symbol(
  "chatbot-fetch-messages-patched"
);

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!ChatChannel[CHATBOT_FETCH_MESSAGES_PATCHED]) {
    const originalFetchMessages = ChatChannel.prototype.fetchMessages;

    ChatChannel.prototype.fetchMessages = async function (findArgs = {}) {
      if (this.messagesLoader.loading) {
        return originalFetchMessages.call(this, findArgs);
      }

      await originalFetchMessages.call(this, findArgs);

      if (
        findArgs.fetch_from_last_read &&
        this.args.channel?.chatable?.type === "DirectMessage" &&
        this.args.channel?.unicodeTitle === this.siteSettings.chatbot_bot_user
      ) {
        const lastMessageId = this.messagesManager.messages.at(-1)?.id;

        if (lastMessageId) {
          this.scrollToMessageId(lastMessageId);
        }
      }
    };

    ChatChannel[CHATBOT_FETCH_MESSAGES_PATCHED] = true;
  }

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

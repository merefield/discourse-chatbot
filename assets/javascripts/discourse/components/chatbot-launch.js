import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { defaultHomepage } from "discourse/lib/utilities";
import Composer from "discourse/models/composer";
import I18n from "I18n";

export default class ContentLanguageDiscovery extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;
  @service composer;

  get showChatbotButton() {
    const { currentRouteName } = this.router;
    return (
      this.currentUser &&
      this.siteSettings.chatbot_enabled &&
      currentRouteName === `discovery.${defaultHomepage()}` &&
      this.siteSettings.chatbot_quick_access_talk_button &&
      ((this.siteSettings.chat_enabled &&
        this.siteSettings.chatbot_permitted_in_chat) ||
        (this.siteSettings.chatbot_permitted_in_private_messages &&
          this.siteSettings.chatbot_quick_access_talk_in_private_message))
    );
  }

  @action
  startChatting() {
    if (!this.siteSettings.chatbot_quick_access_talk_in_private_message) {
      this.chat
        .upsertDmChannelForUsernames([this.siteSettings.chatbot_bot_user])
        .then((chatChannel) => {
          this.router.transitionTo("chat.channel", ...chatChannel.routeModels);
        });
    } else {
      this.composer.focusComposer({
        fallbackToNewTopic: true,
        openOpts: {
          action: Composer.PRIVATE_MESSAGE,
          recipients: this.siteSettings.chatbot_bot_user,
          topicTitle: I18n.t("chatbot.pm_prefix"),
          archetypeId: "private_message",
          draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
          hasGroups: false,
          warningsDisabled: true,
        },
      });
    }
  }
}

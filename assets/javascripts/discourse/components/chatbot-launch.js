import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ContentLanguageDiscovery extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;

  get showChatbotButton() {
    return (
      this.currentUser &&
      this.siteSettings.chat_enabled &&
      this.siteSettings.chatbot_enabled &&
      this.siteSettings.chatbot_permitted_in_chat &&
      this.siteSettings.chatbot_quick_access_chat_button
    );
  }

  @action
  startChatting() {
    this.chat
      .upsertDmChannelForUsernames([this.siteSettings.chatbot_bot_user])
      .then((chatChannel) => {
        this.router.transitionTo("chat.channel", ...chatChannel.routeModels);
      });
  }
}

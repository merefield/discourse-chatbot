import Component from '@glimmer/component';
import { inject as service } from "@ember/service";
// import I18n from "I18n";
import { action } from '@ember/object';
// import { tracked } from '@glimmer/tracking';

export default class ContentLanguageDiscovery extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;

  get showChatbotButton () {
    return this.currentUser
  }

  @action
  startChatting () {
    this.chat
      .upsertDmChannelForUsernames([this.siteSettings.chatbot_bot_user])
      .then((chatChannel) => {
        this.router.transitionTo("chat.channel", ...chatChannel.routeModels);
      });
  }
}

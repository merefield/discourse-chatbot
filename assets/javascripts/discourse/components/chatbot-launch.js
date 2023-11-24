import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { defaultHomepage } from "discourse/lib/utilities";
import Composer from "discourse/models/composer";
import I18n from "I18n";
import User from "discourse/models/user";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";

export default class ContentLanguageDiscovery extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;
  @service composer;

  @tracked botUser = null;

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
  getBotUser() {
    User.findByUsername(this.siteSettings.chatbot_bot_user, {}).then((user) => {
      this.botUser = user;
    });
  }

  get chatbotLaunchUseAvatar() {
    return this.siteSettings.chatbot_quick_access_bot_user_icon === "";
  }

  get chatbotLaunchIcon() {
    return this.siteSettings.chatbot_quick_access_bot_user_icon;
  }

  @action
  async startChatting() {
    if (this.siteSettings.chatbot_kicks_off) {

      let result = await ajax('/chatbot/start_bot_convo', {
        type: "POST",
      });

      DiscourseURL.redirectTo(`/t/${result.topic_id}`);
    } else {
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
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { defaultHomepage } from "discourse/lib/utilities";
import Composer from "discourse/models/composer";
import User from "discourse/models/user";
import I18n from "I18n";

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
      this.currentUser.chatbot_access &&
      currentRouteName === `discovery.${defaultHomepage()}` &&
      this.siteSettings.chatbot_quick_access_talk_button !== "off" &&
      ((this.siteSettings.chat_enabled &&
        this.siteSettings.chatbot_permitted_in_chat) ||
        (this.siteSettings.chatbot_permitted_in_private_messages &&
          this.siteSettings.chatbot_quick_access_talk_button ===
            "personal message"))
    );
  }

  @action
  getBotUser() {
    User.findByUsername(this.siteSettings.chatbot_bot_user, {}).then((user) => {
      this.botUser = user;
    });
  }

  get chatbotLaunchUseAvatar() {
    return this.siteSettings.chatbot_quick_access_talk_button_bot_icon === "";
  }

  get chatbotLaunchIcon() {
    return this.siteSettings.chatbot_quick_access_talk_button_bot_icon;
  }

  @action
  async startChatting() {
    if (this.siteSettings.chatbot_quick_access_bot_kicks_off) {
      let result = await ajax("/chatbot/start_bot_convo", {
        type: "POST",
      });

      if (
        this.siteSettings.chatbot_quick_access_talk_button ===
        "personal message"
      ) {
        DiscourseURL.redirectTo(`/t/${result.topic_id}`);
      } else {
        this.chat
          .upsertDmChannel({ usernames: [this.siteSettings.chatbot_bot_user] })
          .then((chatChannel) => {
            this.router.transitionTo(
              "chat.channel",
              ...chatChannel.routeModels
            );
          });
      }
    } else {
      if (this.siteSettings.chatbot_quick_access_talk_button === "chat") {
        this.chat
          .upsertDmChannel({ usernames: [this.siteSettings.chatbot_bot_user] })
          .then((chatChannel) => {
            this.router.transitionTo(
              "chat.channel",
              ...chatChannel.routeModels
            );
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

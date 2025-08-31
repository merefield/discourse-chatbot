import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import Composer from "discourse/models/composer";
import User from "discourse/models/user";
import I18n, { i18n } from "discourse-i18n";

export default class ContentLanguageDiscovery extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;
  @service composer;
  @service site;
  @service toasts;

  @tracked botUser = null;

  get showChatbotButton() {
    const baseRoute = this.router.currentRouteName.split(".")[0];
    const subRoute = this.router.currentRouteName.split(".")[1];
    return (
      this.currentUser &&
      this.siteSettings.chatbot_enabled &&
      this.currentUser.chatbot_access &&
      (baseRoute === "discovery" ||
        (baseRoute === "tags" && subRoute === "intersection") ||
        (!this.site.mobileView && baseRoute === "topic")) &&
      this.siteSettings.chatbot_quick_access_talk_button !== "off" &&
      ((this.siteSettings.chat_enabled &&
        this.siteSettings.chatbot_permitted_in_chat) ||
        (this.siteSettings.chatbot_permitted_in_private_messages &&
          this.siteSettings.chatbot_quick_access_talk_button ===
            "personal message"))
    );
  }

  get chatbotLaunchClass() {
    return this.args.post ? "post post-action-menu__chatbot" : "";
  }

  get title() {
    return this.args.post ? "chatbot.post_launch.title" : "";
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

  get primaryButton() {
    return !this.args.post;
  }

  @action
  async startChatting() {
    if (this.args?.post?.id) {
      this.toasts.success({
        duration: 3000,
        showProgressBar: true,
        data: {
          message: I18n.t("chatbot.post_launch.thinking"),
          icon: this.siteSettings.chatbot_quick_access_talk_button_bot_icon,
        },
      });
    }
    let result = {};
    if (this.siteSettings.chatbot_quick_access_bot_kicks_off) {
      result = await ajax("/chatbot/start_bot_convo", {
        type: "POST",
        data: {
          post_id: this.args?.post?.id,
        },
      });
    }

    if (
      this.siteSettings.chatbot_quick_access_talk_button === "personal message"
    ) {
      if (this.siteSettings.chatbot_quick_access_bot_kicks_off) {
        DiscourseURL.redirectTo(`/t/${result.topic_id}`);
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
    } else {
      this.chat
        .upsertDmChannel({
          usernames: [
            this.siteSettings.chatbot_bot_user,
            this.currentUser.username,
          ],
        })
        .then((chatChannel) => {
          this.router.transitionTo("chat.channel", ...chatChannel.routeModels);
        });
    }
  }

  <template>
    {{#if this.showChatbotButton}}
      <DButton
        {{didInsert this.getBotUser}}
        @id={{if this.primaryButton "chatbot-btn"}}
        @class={{concatClass "chatbot-btn" this.chatbotLaunchClass}}
        ...attributes
        @action={{this.startChatting}}
        @title={{this.title}}
      >
        {{#if this.chatbotLaunchUseAvatar}}
          {{avatar this.botUser imageSize="medium"}}
        {{else}}
          {{icon this.chatbotLaunchIcon}}
        {{/if}}
        {{#if this.primaryButton}}
          <label class="d-button-label">{{i18n
              "chatbot.title_capitalized"
            }}</label>
        {{/if}}
      </DButton>
    {{/if}}
  </template>
}

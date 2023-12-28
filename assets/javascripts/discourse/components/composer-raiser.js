import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Composer from "discourse/models/composer";

export default class ComposerRaiserCompopnent extends Component {
  @service siteSettings;
  @service currentUser;
  @service site;
  @service composer;

  BOT_USER_ID = -4;

  @action
  raiseComposer() {
    if (
      !(
        this.site.mobileView &&
        this.currentUser.custom_fields
          .chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile
      ) &&
      this.args.model.current_post_number === 1
    ) {
      this.composer.focusComposer({
        fallbackToNewTopic: true,
        openOpts: {
          action: Composer.REPLY,
          recipients: this.siteSettings.chatbot_bot_user,
          draftKey: this.args.model.get("draft_key"),
          topic: this.args.model,
          hasGroups: false,
          warningsDisabled: true,
        },
      });
    }
  }

  get isBotConversation() {
    return (
      this.currentUser &&
      this.args.model.archetype === "private_message" &&
      this.args.model.user_id === this.BOT_USER_ID
    );
  }
}

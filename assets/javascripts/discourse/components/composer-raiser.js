import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Composer from "discourse/models/composer";

export default class ComposerRaiserCompopnent extends Component {
  @service siteSettings;
  @service currentUser;
  @service composer;

  BOT_USER_ID = -4;

  @action
  raiseComposer() {
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

  get isBotConversation() {
    return this.currentUser && this.args.model.user_id === this.BOT_USER_ID;
  }
}

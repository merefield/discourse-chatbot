import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { scheduleOnce } from "@ember/runloop";

export default class ComposerRaiserCompopnent extends Component {
  @service siteSettings;
  @service currentUser;
  @service site;
  @service composer;

  BOT_USER_ID = -4;

  @action
  async raiseComposer() {
    if (
      !(
        this.site.mobileView &&
        this.currentUser.custom_fields
          .chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile
      ) &&
      this.args.model.current_post_number === 1
    ) {
      scheduleOnce("afterRender", this, this._focusComposer);
    }
  }

  _focusComposer() {
    this.composer.focusComposer({
      topic: this.args.model,
    });
  }

  get isBotConversation() {
    return (
      this.currentUser &&
      this.args.model.archetype === "private_message" &&
      this.args.model.user_id === this.BOT_USER_ID
    );
  }

  <template>
    {{#if this.isBotConversation}}
      <div {{didInsert this.raiseComposer}} />
    {{/if}}
  </template>
}

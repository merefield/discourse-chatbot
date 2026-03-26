import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class SetChatbot extends Component {
  constructor() {
    super(...arguments);
    this.args.outletArgs.category.custom_fields ||= {};
  }

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  get additionalPromptLabel() {
    return trustHTML(i18n("chatbot.category.auto_response_additional_prompt"));
  }

  @action
  updateAdditionalPrompt(event) {
    this.customFields.chatbot_auto_response_additional_prompt =
      event.target.value;
  }

  <template>
    <section>
      <h3>{{i18n "chatbot.category.settings_label"}}</h3>

      <section class="field">
        {{this.additionalPromptLabel}}
        <textarea
          value={{this.customFields.chatbot_auto_response_additional_prompt}}
          {{on "input" this.updateAdditionalPrompt}}
        ></textarea>
      </section>
    </section>
  </template>
}

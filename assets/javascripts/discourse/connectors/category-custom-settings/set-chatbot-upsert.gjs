import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class SetChatbotUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  get additionalPromptLabel() {
    return trustHTML(i18n("chatbot.category.auto_response_additional_prompt"));
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "chatbot.category.settings_label"}}>
        <form.Object @name="custom_fields" as |customFields|>
          <customFields.Field
            @name="chatbot_auto_response_additional_prompt"
            @title={{this.additionalPromptLabel}}
            @type="textarea"
            as |field|
          >
            <field.Control />
          </customFields.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}

import Component from "@glimmer/component";
import { service } from "@ember/service";
import ChatbotUserPreferences from "../../components/chatbot-user-preferences";

export default class ChatbotUserPreferencesConnector extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.chatbot_enabled}}
      <ChatbotUserPreferences @model={{@model}} />
    {{/if}}
  </template>
}

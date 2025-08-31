import ChatbotUserPreferences from "../../components/chatbot-user-preferences";

<template>
  {{#if this.siteSettings.chatbot_enabled}}
    <ChatbotUserPreferences @model={{this.model}} />
  {{/if}}
</template>

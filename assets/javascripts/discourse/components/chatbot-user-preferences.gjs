import PreferenceCheckbox from "discourse/components/preference-checkbox";
import { i18n } from "discourse-i18n";

<template>
  <label class="control-label">{{i18n "chatbot.user_prefs.title"}}</label>
  <PreferenceCheckbox
    @labelKey="chatbot.user_prefs.prefer_no_quickchat_pm_popup"
    @checked={{@model.custom_fields.chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile}}
  />
</template>

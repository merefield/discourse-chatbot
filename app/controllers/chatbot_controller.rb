
# frozen_string_literal: true
module ::DiscourseChatbot
  class ChatbotController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_plugin_enabled

    def start_bot_convo

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = ::User.find_by(username: bot_username)

      default_opts = {
        post_alert_options: { skip_send_email: true },
        raw: I18n.t("chatbot.kickoff.statement"),
        skip_validations: true,
        title: I18n.t("chatbot.pm_prefix"),
        archetype: Archetype.private_message,
        target_usernames: [current_user.username, bot_user.username].join(",")
      }

      new_post = PostCreator.create!(bot_user, default_opts)

      default_opts = {
        raw: I18n.t("chatbot.kickoff.instructions" ),
        topic_id: new_post.topic_id,
        post_alert_options: { skip_send_email: true },
        post_type: 4,
        skip_validations: true
      }

      new_post = ::PostCreator.create!(bot_user, default_opts)

      response = { topic_id: new_post.topic_id }

      render json: response
    end

    private

    def ensure_plugin_enabled
      unless SiteSetting.chatbot_enabled
        redirect_to path("/")
      end
    end
  end
end

# frozen_string_literal: true
require_dependency 'application_controller'

module DiscourseChatbot
  class ChatbotController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_plugin_enabled

    def start_bot_convo

      response = {}

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = ::User.find_by(username: bot_username)
      channel_type = SiteSetting.chatbot_quick_access_talk_button

      if channel_type == "chat"

        @bot_author = ::User.find_by(username: SiteSetting.chatbot_bot_user)
        @guardian = Guardian.new(@bot_author)

        direct_message = Chat::DirectMessage.for_user_ids([bot_user.id, current_user.id])
        if direct_message
          chat_channel_id = Chat::Channel.find_by(chatable_id: direct_message).id

          last_chat = ::Chat::Message.where(chat_channel_id: chat_channel_id, deleted_at: nil).last

          unless last_chat && last_chat.message == I18n.t("chatbot.quick_access_kick_off.announcement")
            Chat::CreateMessage.call(
              chat_channel_id: chat_channel_id,
              guardian: @guardian,
              message: I18n.t("chatbot.quick_access_kick_off.announcement"),
            )
          end
        end
      elsif channel_type == "personal message"
        default_opts = {
          post_alert_options: { skip_send_email: true },
          raw: I18n.t("chatbot.quick_access_kick_off.announcement"),
          skip_validations: true,
          title: I18n.t("chatbot.pm_prefix"),
          archetype: Archetype.private_message,
          target_usernames: [current_user.username, bot_user.username].join(",")
        }

        new_post = PostCreator.create!(bot_user, default_opts)

        response = { topic_id: new_post.topic_id }
      end

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

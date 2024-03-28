
# frozen_string_literal: true
# require_dependency 'application_controller'

module ::DiscourseChatbot
  class ChatbotController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_plugin_enabled

    def start_bot_convo

      response = {}

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = ::User.find_by(username: bot_username)
      channel_type = SiteSetting.chatbot_quick_access_talk_button

      if channel_type == "chat"

        bot_author = ::User.find_by(username: SiteSetting.chatbot_bot_user)
        guardian = Guardian.new(bot_author)
        chat_channel_id = nil

        direct_message = Chat::DirectMessage.for_user_ids([bot_user.id, current_user.id])

        if direct_message
          chat_channel = Chat::Channel.find_by(chatable_id: direct_message.id, type: "DirectMessageChannel")
          chat_channel_id = chat_channel.id

          #TODO we might need to add a membership if it doesn't exist to prevent a NotFound error in reads controller
          # membership = Chat::UserChatChannelMembership.find_by(user_id: current_user.id, chat_channel_id: chat_channel_id)

          # if membership
          #   membership.update!(following: true)
          #   membership.save!
          # end

          last_chat = ::Chat::Message.find_by(id: chat_channel.latest_not_deleted_message_id)

          unless (last_chat && last_chat.message == I18n.t("chatbot.quick_access_kick_off.announcement")) || last_chat.nil?
            Chat::CreateMessage.call(
              chat_channel_id: chat_channel_id,
              guardian: guardian,
              message: I18n.t("chatbot.quick_access_kick_off.announcement"),
            )
          end

          response = { channel_id: chat_channel_id }
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


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

      evaluation = ::DiscourseChatbot::EventEvaluation.new
      over_quota = evaluation.over_quota(current_user.id)

      kick_off_statement = I18n.t("chatbot.quick_access_kick_off.announcement")

      if SiteSetting.chatbot_user_fields_collection

        trust_level = ::DiscourseChatbot::EventEvaluation.new.trust_level(current_user.id)
        opts = { trust_level: trust_level, user_id: current_user.id }

        start_bot = ::DiscourseChatbot::OpenAiBotRag.new(opts, false)

        system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.rag.private", current_date_time: DateTime.current) }
        assistant_message = { "role": "assistant", "content": I18n.t("chatbot.prompt.quick_access_kick_off.announcement", username: current_user.username) }

        system_message_suffix =  start_bot.get_system_message_suffix(opts)
        system_message[:content] += "  " + system_message_suffix

        messages = [system_message, assistant_message]

        model = start_bot.model_name

        parameters = {
          model: model,
          messages: messages,
          max_completion_tokens: SiteSetting.chatbot_max_response_tokens,
          temperature: SiteSetting.chatbot_request_temperature / 100.0,
          top_p: SiteSetting.chatbot_request_top_p / 100.0,
          frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
          presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0
        }

        res = start_bot.client.chat(
          parameters: parameters
        )

        kick_off_statement = res.dig("choices", 0, "message", "content")
      end

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

          if (last_chat && (over_quota && last_chat.message != I18n.t('chatbot.errors.overquota') || !over_quota && last_chat.message != I18n.t("chatbot.quick_access_kick_off.announcement"))) || last_chat.nil?
            Chat::CreateMessage.call(
              params: {
                chat_channel_id: chat_channel_id,
                message: over_quota ? I18n.t('chatbot.errors.overquota') : kick_off_statement
              },
              guardian: guardian
            )
          end

          response = { channel_id: chat_channel_id }
        end
      elsif channel_type == "personal message"
        default_opts = {
          post_alert_options: { skip_send_email: true },
          raw: over_quota ? I18n.t('chatbot.errors.overquota') : kick_off_statement,
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

# frozen_string_literal: true
module ::DiscourseChatbot

  class MessagePromptUtils < PromptUtils

    def self.create_prompt(opts)

      message_collection = collect_past_interactions(opts[:reply_to_message_or_post_id])
      bot_user_id = opts[:bot_user_id]

      if SiteSetting.chatbot_open_ai_model == "gpt-3.5-turbo"
        if SiteSetting.chatbot_enforce_system_role == true
          messages = []

          messages += message_collection.reverse.map do |cm|
            username = ::User.find(cm.user_id).username
            { "role": (cm.user_id == bot_user_id ? "assistant" : "user"), "content": (cm.user_id == bot_user_id ? "#{cm.message}" : I18n.t("chatbot.prompt.post", username: username, raw: cm.message)) }
          end

          messages << { "role": "system", "content": I18n.t("chatbot.prompt.system") }

          messages
        else
          messages = [{ "role": "system", "content": I18n.t("chatbot.prompt.system") }]

          messages += message_collection.reverse.map do |cm|
            username = ::User.find(cm.user_id).username
            { "role": (cm.user_id == bot_user_id ? "assistant" : "user"), "content": (cm.user_id == bot_user_id ? "#{cm.message}" : I18n.t("chatbot.prompt.post", username: username, raw: cm.message)) }
          end

          if SiteSetting.chatbot_prio_system_role == true
            messages << { "role": "system", "content": I18n.t("chatbot.prompt.systemprio") }
          end

          messages
        end
      else
        content = message_collection.reverse.map do |cm|
          username = ::User.find(cm.user_id).username
          <<~MD
          #{I18n.t("chatbot.prompt.post", username: username, raw: cm.message)}
          ---
          MD
        end

        content.join
      end
    end

    def self.collect_past_interactions(message_or_post_id)
      current_message = ::Chat::Message.find(message_or_post_id)

      message_collection = []

      message_collection << current_message

      collect_amount = SiteSetting.chatbot_max_look_behind

      while message_collection.length < collect_amount do

        if current_message.in_reply_to_id
          current_message = ::Chat::Message.find(current_message.in_reply_to_id)
        else
          prior_message = ::Chat::Message.where(chat_channel_id: current_message.chat_channel_id, deleted_at: nil).where('chat_messages.id < ?', current_message.id).last
          if prior_message.nil?
            break
          else
            current_message = prior_message
          end
        end

        message_collection << current_message
      end

      message_collection
    end
  end
end

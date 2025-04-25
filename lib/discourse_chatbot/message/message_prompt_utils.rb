# frozen_string_literal: true
module ::DiscourseChatbot
  class MessagePromptUtils < PromptUtils
    def self.create_prompt(opts)
      message_collection = collect_past_interactions(opts[:reply_to_message_or_post_id])
      bot_user_id = opts[:bot_user_id]

      messages = []

      messages +=
        message_collection.reverse.map do |cm|
          username = ::User.find(cm.user_id).username
          role = (cm.user_id == bot_user_id ? "assistant" : "user")
          text =
            (
              if SiteSetting.chatbot_api_supports_name_attribute || cm.user_id == bot_user_id
                cm.message
              else
                I18n.t("chatbot.prompt.post", username: username, raw: cm.message)
              end
            )

          content = []

          content << { type: "text", text: text }
          cm.uploads.each do |ul|
            if %w[png webp jpg jpeg gif ico avif].include?(ul.extension) && SiteSetting.chatbot_support_vision == "directly" ||
              ul.extension == "pdf" && SiteSetting.chatbot_support_pdf == true
              role = "user"
              file_path = Discourse.store.path_for(ul)
              base64_encoded_data = Base64.strict_encode64(File.read(file_path))
              if ul.extension == "pdf"
                content << {
                  "type": "file",
                  "file": {
                      "filename": ul.original_filename,
                      "file_data": "data:application/pdf;base64," + base64_encoded_data
                  }
                }
              else
                content << {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/#{ul.extension};base64," + base64_encoded_data
                  }
                }
              end
            end
          end

          if SiteSetting.chatbot_api_supports_name_attribute
            { role: role, name: username, content: content }
          else
            { role: role, content: content }
          end
        end

      messages
    end

    def self.collect_past_interactions(message_or_post_id)
      current_message = ::Chat::Message.find(message_or_post_id)

      message_collection = []

      message_collection << current_message

      collect_amount = SiteSetting.chatbot_max_look_behind

      while message_collection.length < collect_amount
        if current_message.in_reply_to_id
          current_message = ::Chat::Message.find(current_message.in_reply_to_id)
        else
          prior_message =
            ::Chat::Message
              .where(chat_channel_id: current_message.chat_channel_id, thread_id: current_message.thread_id, deleted_at: nil)
              .where("chat_messages.id < ?", current_message.id)
              .last
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

module ::DiscourseChatbot

  class MessagePromptUtils < PromptUtils

    def self.create_prompt(opts)
      message_collection = collect_past_interactions(opts[:reply_to_message_or_post_id])
      # {p.user.username}
       content = message_collection.reverse.map { |p| <<~MD }
       #{p.message}
       ---
       MD
       return content.join
    end


    def self.collect_past_interactions(message_or_post_id)
      current_message = ::ChatMessage.find(message_or_post_id)

      message_collection = []

      message_collection << current_message

      collect_amount = SiteSetting.chatbot_max_look_behind

      while message_collection.length < collect_amount do
        
        if current_message.in_reply_to_id
          current_message = ::ChatMessage.find(current_message.in_reply_to_id)
        else
          prior_message = ::ChatMessage.where(chat_channel_id: current_message.chat_channel_id, deleted_at: nil).where('chat_messages.id < ?', current_message.id).last
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
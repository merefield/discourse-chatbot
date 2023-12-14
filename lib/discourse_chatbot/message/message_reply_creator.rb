# frozen_string_literal: true
module ::DiscourseChatbot
  class MessageReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
      ::DiscourseChatbot.progress_debug_message("5. Creating a new Chat Nessage...")
      begin
        Chat::CreateMessage.call(
          chat_channel_id: @topic_or_channel_id,
          guardian: @guardian,
          message: @message_body,
        )

        presence = PresenceChannel.new("/chat-reply/#{@topic_or_channel_id}")
        presence.leave(user_id: @author.id, client_id: "12345")

        ::DiscourseChatbot.progress_debug_message("6. The Message has been created successfully")
      rescue => e
        ::DiscourseChatbot.progress_debug_message("Problem with the bot Message: #{e}")
        Rails.logger.error("Chatbot: There was a problem: #{e}")
      end
    end
  end
end

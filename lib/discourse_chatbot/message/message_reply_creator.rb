# frozen_string_literal: true
module ::DiscourseChatbot
  class MessageReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
      ::DiscourseChatbot.progress_debug_message("5. Creating a new Chat Nessage...")
      begin
        if @private && @human_participants_count == 1
          # latest_message_id = ::Topic.find(@topic_or_channel_id).posts.order('created_at DESC').first.id
          latest_message_id = ::Chat::Message.where(chat_channel_id: @topic_or_channel_id, deleted_at: nil).order('created_at DESC').first.id

          if @reply_to != latest_message_id
            ::DiscourseChatbot.progress_debug_message("7. The Message was discarded as there is a newer human message")
            # do not create a new response if the message is not the latest
            return
          end
        end

        params =  {
          chat_channel_id: @topic_or_channel_id,
          message: @message_body
        }

        params.merge!(thread_id: @thread_id) if @thread_id.present?

        Chat::CreateMessage.call(
          params: params,
          guardian: @guardian
        )
        begin
          presence = PresenceChannel.new("/chat-reply/#{@topic_or_channel_id}")
          presence.leave(user_id: @author.id, client_id: "12345")
        rescue
          # ignore issues with permissions related to communicating presence
        end

        ::DiscourseChatbot.progress_debug_message("6. The Message has been created successfully")
      rescue => e
        ::DiscourseChatbot.progress_debug_message("Problem with the bot Message: #{e}")
        Rails.logger.error("Chatbot: There was a problem: #{e}")
      end
    end
  end
end

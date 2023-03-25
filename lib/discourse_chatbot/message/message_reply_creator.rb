# frozen_string_literal: true
module ::DiscourseChatbot
  class MessageReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
      ::DiscourseChatbot.progress_debug_message("5. Creating a new Chat Nessage...")

        default_opts = {
          content: @message_body,
          chat_channel: ::Chat::Channel.find(@topic_or_channel_id),
          user: @author
          # TODO need a way to suppress notifications/emails?
        }

        begin
          new_message = ::Chat::MessageCreator.create(default_opts)
          ::DiscourseChatbot.progress_debug_message("6. The message has been created successfully")
        rescue => e
          puts "Problem with the message: #{e}"
          Rails.logger.error ("OpenAIBot: There was a problem: #{e}")
        end
    end
  end
end

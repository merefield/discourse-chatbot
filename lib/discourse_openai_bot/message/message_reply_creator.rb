module ::DiscourseOpenAIBot
  class MessageReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
        puts "4. Creating a new reply message..."

        default_opts = {
          content: @message_body,
          chat_channel:  ChatChannel.find(@topic_or_channel_id),
          user: @author
          # TODO need a way to suppress notifications/emails?
        }

        begin
          new_message = Chat::ChatMessageCreator.create(default_opts)
          puts "The message has been created successfully"
        rescue => e
          puts "Problem with the message: #{e}"
          Rails.logger.error ("OpenAIBot: There was a problem: #{e}")
        end
    end
  end
end

module ::DiscourseChatbot
  class PostReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
        puts "4. Creating a new reply message..."

        default_opts = {
          raw: @message_body,
          topic_id: @topic_or_channel_id,
          reply_to_post_number: @reply_to,
          post_alert_options: { skip_send_email: true },
          skip_validations: true
        }

        begin
          new_post = PostCreator.create!(@author, default_opts)
          puts "The message has been created successfully"
        rescue => e
          puts "Problem with the message: #{e}"
          Rails.logger.error ("AI Bot: There was a problem: #{e}")
        end
    end
  end
end

module DiscourseFrotz
  class ReplyCreator

    def initialize(options = {})
      @author = options[:user]
      @reply_to = options[:reply_to]
    end

    def create(raw_content)

        params = {
          topic_id: @reply_to.topic_id,
          reply_to_post_number: @reply_to.post_number,
          raw: raw_content
        }

        if (@reply_to.topic && @reply_to.topic.category)
          params[:category] = @reply_to.topic.category.slug
        end

        puts "Creating a new reply message..."

        if raw_content.blank? 
          raw_content = '...'
        end
        
        default_opts = {
          raw: raw_content,
          topic_id: @reply_to.topic_id,
          reply_to_post_number: @reply_to.post_number,
          post_alert_options: { skip_send_email: true },
          skip_validations: true
        }
        begin
          new_post = PostCreator.create!(@author, default_opts)
          puts "The message has been created successfully"
        rescue => e
          puts "Problem with the message: #{e}"
          Rails.logger.error ("FroztBot: There was a problem: #{e}")
        end

    end
  end
end

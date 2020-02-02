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

        is_private_msg = (@reply_to.topic && @reply_to.topic.private_message?)
        unless is_private_msg
          puts "Creating a new reply message..."
          result = NewPostManager.new(@author, params).perform
          if result.success?
            puts "The message has been created successfully"
          else
            puts "Problem with the message:"
            puts result.errors.inspect
          end
        else
          puts "Skipping since the post belongs to a private conversation"
        end

    end

  end
end

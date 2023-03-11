# frozen_string_literal: true
module ::DiscourseChatbot
  class ReplyCreator

    def initialize(options = {})
      @author = ::User.find_by(id: options[:bot_user_id])
      @reply_to = options[:reply_to_message_or_post_id]
      @reply_to_post_number = options[:original_post_number]
      @topic_or_channel_id = options[:topic_or_channel_id]
      @message_body = options[:message_body]
      if @message_body.blank?
        @message_body = '...'
      end
    end

    def create
      raise "Overwrite me!"
    end
  end
end

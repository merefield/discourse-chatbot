# frozen_string_literal: true
module ::DiscourseChatbot
  class ReplyCreator

    def initialize(options = {})
      @options = options
      @author = options[:post_as_user] ? ::User.find_by(id: options[:user_id]) : ::User.find_by(id: options[:bot_user_id])
      @guardian = Guardian.new(@author)
      @reply_to = options[:reply_to_message_or_post_id]
      @reply_to_post_number = options[:original_post_number]
      @topic_or_channel_id = options[:topic_or_channel_id]
      @thread_id = options[:thread_id]
      @message_body = options[:reply]
      @is_private_msg = options[:is_private_msg]
      @private = options[:private]
      @human_participants_count = options[:human_participants_count]
      @inner_thoughts = options[:inner_thoughts]
      @trust_level = options[:trust_level]
      @chatbot_bot_type = options[:chatbot_bot_type]
      if @message_body.blank?
        @message_body = I18n.t('chatbot.errors.retries')
      end
    end

    def create
      raise "Overwrite me!"
    end
  end
end

module ::DiscourseChatbot

  class MessageEvaluation < EventEvaluation

    # DELAY_IN_SECONDS = 3
    # MESSAGE = "message"

    def on_submission(submission)
      puts "2. evaluation"
      
      chat_message = submission

      user_id = chat_message.user
      channel_id = chat_message.chat_channel_id
      message_contents = chat_message.message
      in_reply_to_id = chat_message.in_reply_to_id

      # remove the 'quote' blocks
      #post_contents.gsub!(%r{\[quote.*?\][^\[]+\[/quote\]}, '')

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = User.find_by(username: bot_username)
      bot_user_id = bot_user.id

      mentions_bot_name = message_contents.downcase =~ /@#{bot_username.downcase}\b/

      prior_message = ::ChatMessage.where(chat_channel_id: channel_id).second_to_last
      replied_to_user = nil
      if in_reply_to_id
        puts "found it's a reply to a prior message"
        replied_to_user = ::ChatMessage.find(in_reply_to_id).user
      end
      
      last_message_was_bot = (replied_to_user && replied_to_user.id == bot_user_id) || (prior_message.user_id == bot_user_id && in_reply_to_id == nil)
      
      if bot_user && (user_id != bot_user_id) && (mentions_bot_name || last_message_was_bot)
        opts = {
            type: MESSAGE,
            user_id: user_id,
            bot_user_id: bot_user_id,
            reply_to_message_or_post_id: chat_message.id,
            topic_or_channel_id: channel_id,
           # conversation_id: topic.conversation_id || nil,
            message_body: message_contents.gsub(bot_username.downcase, '').gsub(bot_username, '')
          }
          puts "3. invocation"
          job_class = ::Jobs::ChatbotReplyJob
          invoke_background_job(job_class, opts)
      end
    end

    private

    def invoke_background_job(job_class, opts)
      super(job_class, opts)
    end

  end
end

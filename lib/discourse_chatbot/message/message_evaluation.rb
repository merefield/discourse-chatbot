module ::DiscourseChatbot

  class MessageEvaluation < EventEvaluation

    # DELAY_IN_SECONDS = 3
    # MESSAGE = "message"

    DIRECT_MESSAGE = "DirectMessage"

    def on_submission(submission)
      puts "2. evaluation"
      
      chat_message = submission

      user_id = chat_message.user
      channel_id = chat_message.chat_channel_id
      message_contents = chat_message.message
      in_reply_to_id = chat_message.in_reply_to_id

      over_quota = over_quota(user_id)

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

      direct_chat = ChatChannel.find(channel_id).chatable_type == DIRECT_MESSAGE
      bot_chat_channel = User.find(bot_user_id).user_chat_channel_memberships.where(chat_channel_id: channel_id)
      
      talking_to_bot = (direct_chat && bot_chat_channel) || (replied_to_user && replied_to_user.id == bot_user_id) || (prior_message.user_id == bot_user_id && in_reply_to_id == nil)
      
      if bot_user && (user_id != bot_user_id) && (mentions_bot_name || talking_to_bot)
        opts = {
            type: MESSAGE,
            user_id: user_id,
            bot_user_id: bot_user_id,
            reply_to_message_or_post_id: chat_message.id,
            topic_or_channel_id: channel_id,
            over_quota: over_quota,
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

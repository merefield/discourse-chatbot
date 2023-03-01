module ::DiscourseChatbot

  class PostEvaluation < EventEvaluation

    # DELAY_IN_SECONDS = 3
    # POST = "post"

    def on_submission(submission)
      puts "2. evaluation"

      post = submission

      user = post.user
      topic = post.topic
      over_quota = over_quota(user.id)

      post_contents = post.raw.to_s

      # remove the 'quote' blocks
      post_contents.gsub!(%r{\[quote.*?\][^\[]+\[/quote\]}, '')

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = ::User.find_by(username: bot_username)

      mentions_bot_name = post_contents.downcase =~ /@#{bot_username.downcase}\b/

      if post.post_number > 1
        prior_post = ::Post.where(topic_id: topic.id).second_to_last
        last_post_was_bot = (post.reply_to_user_id == bot_user.id) || (prior_post.user_id == bot_user.id)
      else
        last_post_was_bot = false
      end

      user_id = user.id

      if bot_user && (user != bot_user) && (mentions_bot_name || last_post_was_bot)
          opts = {
            type: POST,
            user_id: user_id,
            bot_user_id: bot_user.id,
            reply_to_message_or_post_id: post.id,
            topic_or_channel_id: topic.id,
            over_quota: over_quota,
           # conversation_id: topic.conversation_id || nil,
            message_body: post_contents.gsub(bot_username.downcase, '').gsub(bot_username, '')
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

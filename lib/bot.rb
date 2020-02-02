module DiscourseFrotz

  class Bot

    DELAY_IN_SECONDS = 0

    def on_post_created(post)

      user = post.user
      topic = post.topic

      post_contents = post.raw.to_s

      # remove the 'quote' blocks
      post_contents.gsub!(%r{\[quote.*?\][^\[]+\[/quote\]}, '')

      bot_username = SiteSetting.frotz_bot_user
      bot_user = User.find_by(username: bot_username)

      mentions_bot_name = post_contents.downcase =~ /@#{bot_username.downcase}\b/

      last_post_was_bot = (post.reply_to_user_id == bot_user.id) || (post.post_number - 1 > 0 && Post.find_by(post_number: (post.post_number - 1)).user_id == bot_user.id)

      user_id = user.id

      if bot_user && (user != bot_user) && (mentions_bot_name || last_post_was_bot)
          opts = {
            user_id: user_id,
            bot_user_id: bot_user.id,
            reply_to_post_id: post.id,
            message_body: post_contents.gsub(bot_username.downcase, '').gsub(bot_username, '')
          }
          job_class = ::Jobs::DiscourseFrotzCallFrotzBotJob
          invoke_background_job(job_class, opts)
      end
    end

    private

    def invoke_background_job(job_class, opts)
      delay_in_seconds = DELAY_IN_SECONDS.to_i
      if delay_in_seconds > 0
        job_class.perform_in(delay_in_seconds.seconds, opts)
      else
        job_class.perform_async(opts)
      end
    end

  end
end

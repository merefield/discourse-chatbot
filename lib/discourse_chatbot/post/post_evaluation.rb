# frozen_string_literal: true
module ::DiscourseChatbot

  class PostEvaluation < EventEvaluation

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

      explicit_reply_to_bot = false
      last_post_was_bot = false

      if post.post_number > 1
        prior_post = ::Post.where(topic_id: topic.id).second_to_last
        last_post_was_bot = prior_post.user_id == bot_user.id

        explicit_reply_to_bot = post.reply_to_user_id == bot_user.id
      else
        if topic.private_message? && (::TopicUser.where(topic_id: topic.id).where(posted: false).uniq(&:user_id).pluck(:user_id).include? bot_user.id)
          explicit_reply_to_bot = true
        end
      end

      user_id = user.id

      existing_human_participants = ::TopicUser.where(topic_id: topic.id).where(posted: true).where('user_id not in (?)', [bot_user.id]).uniq(&:user_id).pluck(:user_id)

      human_participants_count = (existing_human_participants << user.id).uniq.count
      puts "humans: #{human_participants_count}"
      if bot_user && (user != bot_user) && (mentions_bot_name || explicit_reply_to_bot || (last_post_was_bot && human_participants_count == 1))
        opts = {
          type: POST,
          user_id: user_id,
          bot_user_id: bot_user.id,
          reply_to_message_or_post_id: post.id,
          original_post_number: post.post_number,
          topic_or_channel_id: topic.id,
          over_quota: over_quota,
          message_body: post_contents.gsub(bot_username.downcase, '').gsub(bot_username, '')
        }
        puts "3. invocation"
        job_class = ::Jobs::ChatbotReplyJob
        invoke_background_job(job_class, opts)
        true
      else
        false
      end
    end

    private

    def invoke_background_job(job_class, opts)
      super(job_class, opts)
    end

  end
end

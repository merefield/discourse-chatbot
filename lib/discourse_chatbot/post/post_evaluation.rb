# frozen_string_literal: true
module ::DiscourseChatbot

  class PostEvaluation < EventEvaluation

    def on_submission(submission)
      ::DiscourseChatbot.progress_debug_message("2. evaluation")

      if !(opts = trigger_response(submission)).blank?
        ::DiscourseChatbot.progress_debug_message("3. invocation")

        job_class = ::Jobs::ChatbotReply
        invoke_background_job(job_class, opts)
        true
      else
        false
      end
    end

    def trigger_response(submission)
      post = submission

      user = post.user
      topic = post.topic
      category_id = topic.category_id

      post_contents = post.raw.to_s

      # remove the 'quote' blocks
      post_contents.gsub!(/\[quote.*?\](.*?)\[\/quote\]/m, '')

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = ::User.find_by(username: bot_username)

      mentions_bot_name = post_contents.downcase =~ /@#{bot_username.downcase}\b/

      explicit_reply_to_bot = false
      prior_user_was_bot = false

      if post.post_number > 1
        last_other_posting_user_id = ::Post.where(topic_id: topic.id).order(created_at: :desc).limit(5).where.not(user_id: user.id).first&.user_id
        prior_user_was_bot = last_other_posting_user_id == bot_user.id

        explicit_reply_to_bot = post.reply_to_user_id == bot_user.id
      else
        if (topic.private_message? && (::TopicUser.where(topic_id: topic.id).where(posted: false).uniq(&:user_id).pluck(:user_id).include? bot_user.id)) ||
             (Array(SiteSetting.chatbot_auto_respond_categories.split("|")).include? post.topic.category_id.to_s)
          explicit_reply_to_bot = true
        end
      end

      user_id = user.id

      existing_human_participants = ::TopicUser.where(topic_id: topic.id).where(posted: true).where('user_id not in (?)', [bot_user.id]).uniq(&:user_id).pluck(:user_id)

      human_participants_count = (existing_human_participants << user.id).uniq.count

      ::DiscourseChatbot.progress_debug_message("humans found in this convo: #{human_participants_count}")

      if bot_user && (user.id > 0) && (mentions_bot_name || explicit_reply_to_bot ||(prior_user_was_bot && human_participants_count == 1))
        opts = {
          type: POST,
          private: topic.archetype == Archetype.private_message,
          user_id: user_id,
          bot_user_id: bot_user.id,
          reply_to_message_or_post_id: post.id,
          original_post_number: post.post_number,
          topic_or_channel_id: topic.id,
          category_id: category_id,
          over_quota: over_quota(user.id),
          trust_level: trust_level(user.id),
          human_participants_count: human_participants_count,
          message_body: post_contents.gsub(bot_username.downcase, '').gsub(bot_username, '')
        }
      else
        false
      end
    end
  end
end

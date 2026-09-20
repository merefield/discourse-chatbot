# frozen_string_literal: true
module DiscourseChatbot
  module Post
    class PostEvaluation < ::DiscourseChatbot::EventEvaluation
      def on_submission(submission)
        ::DiscourseChatbot.progress_debug_message("2. evaluation")

        if (opts = trigger_response(submission)).present?
          ::DiscourseChatbot.progress_debug_message("3. invocation")

          job_class = ::Jobs::ChatbotReply
          invoke_background_job(job_class, opts)
          true
        else
          false
        end
      end

      def on_edit(post, previous_raw)
        bot_username = SiteSetting.chatbot_bot_user
        return false unless mentions_bot?(post.raw, bot_username)
        return false if mentions_bot?(previous_raw, bot_username)

        on_submission(post)
      end

      def trigger_response(submission)
        post = submission

        user = post.user
        topic = post.topic
        category_id = topic.category_id

        post_contents = post.raw.to_s

        # remove the 'quote' blocks
        post_contents.gsub!(%r{\[quote.*?\](.*?)\[/quote\]}m, "")

        bot_username = SiteSetting.chatbot_bot_user
        bot_user = ::User.find_by(username: bot_username)

        return false unless bot_user

        mentions_bot_name = mentions_bot?(post_contents, bot_username)
        one_to_one_pm =
          topic.private_message? && !topic.topic_allowed_groups.exists? &&
            topic.topic_allowed_users.pluck(:user_id).sort == [user.id, bot_user.id].sort

        automatic_replies_allowed =
          topic.private_message? || SiteSetting.chatbot_unlimited_topic_auto_replies ||
            (
              SiteSetting.chatbot_auto_reply_up_to_post_count > 0 &&
                topic.posts_count <= SiteSetting.chatbot_auto_reply_up_to_post_count
            )

        explicit_reply_to_bot = false
        prior_user_was_bot = false

        if post.post_number > 1
          last_other_posting_user_id =
            ::Post
              .where(topic_id: topic.id)
              .order(created_at: :desc)
              .limit(5)
              .where.not(user_id: user.id)
              .where("user_id > 0")
              .first
              &.user_id
          prior_user_was_bot = last_other_posting_user_id == bot_user.id

          explicit_reply_to_bot = post.reply_to_user_id == bot_user.id
        else
          if (topic.private_message? && topic.topic_allowed_users.exists?(user_id: bot_user.id)) ||
               (
                 automatic_replies_allowed &&
                   SiteSetting.chatbot_auto_respond_categories.split("|").include?(category_id.to_s)
               )
            explicit_reply_to_bot = true
          end
        end

        user_id = user.id

        existing_human_participants =
          ::TopicUser
            .where(topic_id: topic.id)
            .where(posted: true)
            .where.not(user_id: bot_user.id)
            .where("user_id > 0")
            .distinct
            .pluck(:user_id)

        human_participants_count = (existing_human_participants << user.id).uniq.count

        ::DiscourseChatbot.progress_debug_message(
          "humans found in this convo: #{human_participants_count}",
        )
        ::DiscourseChatbot.progress_debug_message(
          "reply trigger for post #{post.id}: one_to_one_pm=#{one_to_one_pm}, " \
            "mention=#{mentions_bot_name}, explicit_reply=#{explicit_reply_to_bot}, " \
            "prior_user_was_bot=#{prior_user_was_bot}, automatic_replies_allowed=#{automatic_replies_allowed}",
        )

        if bot_user && (user.id > 0) &&
             (
               one_to_one_pm || mentions_bot_name || explicit_reply_to_bot ||
                 (automatic_replies_allowed && prior_user_was_bot && human_participants_count == 1)
             )
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
            automatic_topic_reply:
              !topic.private_message? && !mentions_bot_name && post.reply_to_user_id != bot_user.id,
            message_body: post_contents.gsub(bot_username.downcase, "").gsub(bot_username, ""),
          }
        else
          false
        end
      end

      private

      def mentions_bot?(raw, bot_username)
        raw
          .to_s
          .gsub(%r{\[quote.*?\](.*?)\[/quote\]}m, "")
          .match?(/@#{Regexp.escape(bot_username)}\b/i)
      end
    end
  end
end

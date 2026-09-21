# frozen_string_literal: true

module DiscourseChatbot
  class SystemOneContext
    HISTORY_LENGTH = 4
    CONTEXT_CHAR_LIMIT = 2000

    def self.for_submission(submission, bot_user_id: nil, history_length: HISTORY_LENGTH)
      return {} unless submission
      bot_user_id ||= ::User.find_by(username: SiteSetting.chatbot_bot_user)&.id
      audit_prefix = "#{::Post.sanitize_sql_like(::DiscourseChatbot::INNER_THOUGHTS_POST_PREFIX)}%"

      if submission.is_a?(::Post)
        topic = submission.topic
        category = topic.category
        history =
          topic
            .posts
            .where("post_number < ?", submission.post_number)
            .where(post_type: ::Post.types[:regular], hidden: false, deleted_at: nil)
            .where.not("user_id = ? AND raw LIKE ?", bot_user_id || 0, audit_prefix)
            .order(post_number: :desc)
            .limit(history_length)
            .pluck(:user_id, :raw)
        title = topic.title
      else
        channel = submission.chat_channel
        category = channel.chatable if channel.chatable_type == "Category"
        history =
          channel
            .chat_messages
            .where(thread_id: submission.thread_id, deleted_at: nil)
            .where("id < ?", submission.id)
            .where.not("user_id = ? AND message LIKE ?", bot_user_id || 0, audit_prefix)
            .order(id: :desc)
            .limit(history_length)
            .pluck(:user_id, :message)
        title = channel.name
      end

      {
        title: title,
        category: category && { name: category.name, description: category.description_text },
        preceding_messages:
          history.reverse.map do |user_id, text|
            {
              role: user_id == bot_user_id ? "assistant" : "user",
              text: text.first(CONTEXT_CHAR_LIMIT),
            }
          end,
      }
    end
  end
end

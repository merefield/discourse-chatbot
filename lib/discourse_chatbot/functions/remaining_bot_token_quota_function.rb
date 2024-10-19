# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class RemainingBotTokenQuotaFunction < Function

    def name
      'remaining_bot_token_quota'
    end

    def description
      I18n.t("chatbot.prompt.function.remaining_bot_token_quota.description")
    end

    def parameters
      []
    end

    def required
      []
    end

    def process(args, opts)
      begin
        super(args)
        user_id = opts[:user_id]

        remaining_quota = UserCustomField.find_by(user_id: user_id, name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD)

        {
          answer: I18n.t("chatbot.prompt.function.remaining_bot_token_quota.answer", quota: remaining_quota.value),
          token_usage: 0
        }
      rescue
        {
          answer: I18n.t("chatbot.prompt.function.remaining_bot_token_quota.error"),
          token_usage: 0
        }
      end
    end
  end
end

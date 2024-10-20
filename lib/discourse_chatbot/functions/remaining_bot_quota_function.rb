# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class RemainingBotTokenQuotaFunction < Function

    def name
      'remaining_bot_quota'
    end

    def description
      I18n.t("chatbot.prompt.function.remaining_bot_quota.description")
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

        remaining_quota_field_name =  SiteSetting.chatbot_quota_basis == "queries" ? CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD : CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD
        remaining_quota = ::DiscourseChatbot::EventEvaluation.new.get_remaining_quota(user_id, remaining_quota_field_name)

        {
          answer: I18n.t("chatbot.prompt.function.remaining_bot_quota.answer", quota: remaining_quota, units: SiteSetting.chatbot_quota_basis ),
          token_usage: 0
        }
      rescue => e
        {
          answer: I18n.t("chatbot.prompt.function.remaining_bot_quota.error", error: e.message),
          token_usage: 0
        }
      end
    end
  end
end

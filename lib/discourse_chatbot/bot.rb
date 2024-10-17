# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot
  class Bot
    def get_response(prompt, opts)
      raise "Overwrite me!"
    end

    def ask(opts)
      user_id = opts[:user_id]
      content = opts[:type] == POST ? PostPromptUtils.create_prompt(opts) : MessagePromptUtils.create_prompt(opts)

      response = get_response(content, opts)

      consume_token_quota(opts[:user_id], response[:total_tokens])
      response
    end

    def consume_token_quota(user_id, token_usage)
      return if token_usage == 0

      current_record = UserCustomField.find_by(user_id: user_id, name: CHATBOT_REMAINING_TOKEN_QUOTA_CUSTOM_FIELD)
      if current_record.present?
        remaining_quota = current_record.value.to_i - token_usage
        current_record.value = remaining_quota.to_s
      else
        max_quota = ::DiscourseChatbot::EventEvaluation.new.get_max_quota(user_id)
        current_record = UserCustomField.create!(user_id: user_id, name: CHATBOT_REMAINING_TOKEN_QUOTA_CUSTOM_FIELD, value: max_quota.to_s)
        remaining_quota = current_record.value.to_i - token_usage
        current_record.value = remaining_quota.to_s
      end
      current_record.save!
    end
  end
end

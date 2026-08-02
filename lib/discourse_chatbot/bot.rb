# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot
  class Bot
    def get_response(prompt, opts)
      raise "Overwrite me!"
    end

    def ask(opts)
      content =
        if opts[:type] == POST
          Post::PostPromptUtils.create_prompt(opts)
        else
          Message::MessagePromptUtils.create_prompt(opts)
        end

      get_response(content, opts)
    ensure
      consume_quota(opts[:user_id], total_tokens)
    end

    def total_tokens
      0
    end

    def consume_quota(user_id, token_usage)
      query_quota = SiteSetting.chatbot_quota_basis == "queries"
      return if token_usage == 0 && !query_quota

      remaining_quota_field_name =
        (
          if query_quota
            CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD
          else
            CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD
          end
        )
      deduction = query_quota ? 1 : token_usage

      current_record = UserCustomField.find_by(user_id: user_id, name: remaining_quota_field_name)

      if current_record.present?
        remaining_quota = current_record.value.to_i - deduction
        current_record.value = remaining_quota.to_s
      else
        max_quota = ::DiscourseChatbot::EventEvaluation.new.get_max_quota(user_id)
        current_record =
          UserCustomField.create!(
            user_id: user_id,
            name: remaining_quota_field_name,
            value: max_quota.to_s,
          )
        remaining_quota = current_record.value.to_i - deduction
        current_record.value = remaining_quota.to_s
      end
      current_record.save!
    end

    def reset_all_quotas
      ::User.all.each do |u|
        max_quota = ::DiscourseChatbot::EventEvaluation.new.get_max_quota(u.id)

        current_record =
          UserCustomField.find_by(
            user_id: u.id,
            name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
          )

        if current_record.present?
          current_record.value = max_quota.to_s
          current_record.save!
        else
          UserCustomField.create!(
            user_id: u.id,
            name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
            value: max_quota.to_s,
          )
        end

        current_record =
          UserCustomField.find_by(
            user_id: u.id,
            name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
          )

        if current_record.present?
          current_record.value = max_quota.to_s
          current_record.save!
        else
          UserCustomField.create!(
            user_id: u.id,
            name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
            value: max_quota.to_s,
          )
        end

        if current_record =
             UserCustomField.find_by(
               user_id: u.id,
               name: ::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD,
             )
          current_record.delete
        end
      end
    end
  end
end

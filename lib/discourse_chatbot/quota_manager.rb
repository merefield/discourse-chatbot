# frozen_string_literal: true

module ::DiscourseChatbot
  class QuotaManager
    def consume(user_id, token_usage)
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

      with_user_lock(user_id) do
        current_record =
          UserCustomField.find_or_initialize_by(user_id: user_id, name: remaining_quota_field_name)
        if current_record.new_record?
          current_record.value = ::DiscourseChatbot::EventEvaluation.new.get_max_quota(user_id).to_s
        end

        current_record.value = (current_record.value.to_i - deduction).to_s
        current_record.save!
      end
    end

    def initialize_remaining_quota(user_id, remaining_quota_field_name, max_quota)
      with_user_lock(user_id) do
        current_record =
          UserCustomField.find_or_initialize_by(user_id: user_id, name: remaining_quota_field_name)
        current_record.update!(value: max_quota.to_s) if current_record.new_record?
        current_record.value.to_i
      end
    end

    def reset_all
      event_evaluation = ::DiscourseChatbot::EventEvaluation.new

      ::User.find_each do |user|
        max_quota = event_evaluation.get_max_quota(user.id)

        with_user_lock(user.id) do
          [
            ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
            ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
          ].each do |remaining_quota_field_name|
            UserCustomField.find_or_initialize_by(
              user_id: user.id,
              name: remaining_quota_field_name,
            ).update!(value: max_quota.to_s)
          end

          UserCustomField.where(
            user_id: user.id,
            name: ::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD,
          ).delete_all
        end
      end
    end

    private

    def with_user_lock(user_id)
      ::User.transaction do
        ::User.lock.find(user_id)
        yield
      end
    end
  end
end

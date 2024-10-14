# frozen_string_literal: true
class ::Jobs::ChatbotQuotaReset < ::Jobs::Scheduled
  sidekiq_options retry: false

  every 1.week

  def execute(args)

    ::User.all.each do |u|
      max_quota = ::DiscourseChatbot::EventEvaluation.new.get_max_quota(u.id)

      current_record = UserCustomField.find_by(user_id: u.id, name: ::DiscourseChatbot::CHATBOT_REMAINING_TOKEN_QUOTA_CUSTOM_FIELD)

      if current_record.present?
        current_record.value = max_quota.to_s
        current_record.save!
      else
        tokens_remaining = max_quota.to_s
        UserCustomField.create!(user_id: u.id, name: ::DiscourseChatbot::CHATBOT_REMAINING_TOKEN_QUOTA_CUSTOM_FIELD, value: tokens_remaining)
      end

      if current_record = UserCustomField.find_by(user_id: u.id, name: ::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD)
        current_record.delete
      end
    end

  end
end

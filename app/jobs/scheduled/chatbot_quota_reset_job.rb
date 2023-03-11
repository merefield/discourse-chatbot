# frozen_string_literal: true
class ::Jobs::ChatbotQuotaResetJob < ::Jobs::Scheduled
  sidekiq_options retry: false

  every 1.week

  def execute(args)

    ::User.all.each do |u|
      if current_record = UserCustomField.find_by(user_id: u.id, name: ::DiscourseChatbot::CHATBOT_QUERIES_CUSTOM_FIELD)
        current_record.value = "0"
        current_record.save!
      else
        current_queries = "0"
        UserCustomField.create!(user_id: u.id, name: ::DiscourseChatbot::CHATBOT_QUERIES_CUSTOM_FIELD, value: current_queries)
      end
    end

  end
end

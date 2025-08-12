# frozen_string_literal: true

class ::Jobs::BackfillChatbotQuotas < ::Jobs::Onceoff
  def execute_onceoff(args)
    return unless SiteSetting.chatbot_enabled

    # Initialize Chatbot Quotas for all users as required
    user_count = User.count
    queries_field_count = UserCustomField.where(name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD).count
    token_field_count = UserCustomField.where(name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD).count
    Rails.logger.info "CHATBOT: Checked presence of Chatbot Custom Fields"
    if user_count > queries_field_count * 2 || user_count > token_field_count * 2
      ::DiscourseChatbot::Bot.new.reset_all_quotas
      Rails.logger.info "CHATBOT: Resetted Chatbot Quotas for all users as many users without required Chatbot Custom Fields"
    end
  end
end

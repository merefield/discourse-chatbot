# frozen_string_literal: true

module ::Jobs
  class ChatbotTokenUsageCleanup < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      return unless SiteSetting.chatbot_enabled && SiteSetting.chatbot_enable_token_usage_tracking
      
      retention_days = SiteSetting.chatbot_token_usage_retention_days
      deleted_count = ::DiscourseChatbot::TokenUsageLogger.cleanup_old_records(retention_days)
      
      Rails.logger.info("Chatbot Token Usage Cleanup: Deleted #{deleted_count} records older than #{retention_days} days")
    end
  end
end

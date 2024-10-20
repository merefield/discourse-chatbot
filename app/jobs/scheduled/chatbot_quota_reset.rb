# frozen_string_literal: true
class ::Jobs::ChatbotQuotaReset < ::Jobs::Scheduled
  sidekiq_options retry: false

  every 1.week

  def execute(args)
    ::DiscourseChatbot::Bot.new.reset_all_quotas
  end
end

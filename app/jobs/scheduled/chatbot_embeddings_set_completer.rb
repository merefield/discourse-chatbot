# frozen_string_literal: true
class ::Jobs::ChatbotEmbeddingsSetCompleter < ::Jobs::Scheduled
  sidekiq_options retry: false

  every 5.minutes

  def execute(args)
    return if !SiteSetting.chatbot_enabled
    return if !SiteSetting.chatbot_embeddings_enabled

    ::DiscourseChatbot::EmbeddingCompletionist.process
  end
end

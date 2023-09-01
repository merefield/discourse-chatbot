# frozen_string_literal: true

# Job is triggered on a Post destruction.
class ::Jobs::ChatbotPostEmbeddingDeleteJob < Jobs::Base
  sidekiq_options retry: false

  def execute(opts)
    begin
      post_id = opts[:id]

      ::DiscourseChatbot.progress_debug_message("101. Deleting a Post Embedding for Post id: #{post_id}")

      process = ::DiscourseChatbot::PostEmbeddingProcess.new
      process.destroy(post_id)
    rescue => e
      Rails.logger.error ("OpenAIBot Post Embedding: There was a problem, but will retry til limit: #{e}")
    end
  end
end

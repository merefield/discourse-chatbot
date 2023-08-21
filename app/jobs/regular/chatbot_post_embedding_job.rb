# frozen_string_literal: true

# Job is triggered on an update to a Post.
class ::Jobs::ChatbotPostEmbeddingJob < Jobs::Base
  sidekiq_options retry: 5, dead: false

  def execute(opts)
    begin
      post_id = opts[:id]

      ::DiscourseChatbot.progress_debug_message("100. Creating/updating a Post Embedding for Post id: #{post_id}")

      post_embedding = ::DiscourseChatbot::EmbeddingProcess.new

      post_embedding.upsert_embedding(post_id)
    rescue => e
      Rails.logger.error ("OpenAIBot Post Embedding: There was a problem, but will retry til limit: #{e}")
    end
  end
end
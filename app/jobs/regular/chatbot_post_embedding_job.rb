# frozen_string_literal: true

# Job is triggered on an update to a Post.
class ::Jobs::ChatbotPostEmbeddingJob < Jobs::Base
  def execute(opts)
    post_id = opts[:post_id]

    post_embedding = ::DiscourseChatbot::EmbeddingProcess.new

    post_embedding.upsert_embedding(post_id)
  end
end

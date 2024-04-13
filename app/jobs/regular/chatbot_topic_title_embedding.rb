# frozen_string_literal: true

# Job is triggered on an update to a Post.
class ::Jobs::ChatbotTopicTitleEmbedding < Jobs::Base
  sidekiq_options retry: 5, dead: false, queue: 'low'

  def execute(opts)
    begin
      topic_id = opts[:id]

      ::DiscourseChatbot.progress_debug_message("100. Creating/updating a Topic Title Embedding for Topic id: #{topic_id}")

      process_topic_title_embedding = ::DiscourseChatbot::TopicTitleEmbeddingProcess.new

      process_topic_title_embedding.upsert(topic_id)
    rescue => e
      Rails.logger.error("Chatbot: Topic Title Embedding: There was a problem, but will retry til limit: #{e}")
    end
  end
end

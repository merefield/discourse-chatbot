# frozen_string_literal: true

# Job is triggered on a Topic destruction.
class ::Jobs::ChatbotTopicTitleEmbeddingDelete < Jobs::Base
  sidekiq_options retry: false

  def execute(opts)
    begin
      topic_id = opts[:id]

      ::DiscourseChatbot.progress_debug_message("101. Deleting a Topic Title Embedding for Topic id: #{topic_id}")

      ::DiscourseChatbot::TopicTitleEmbedding.find_by(topic_id: topic_id).destroy!
    rescue => e
      Rails.logger.error("Chatbot: Topic Title Embedding: There was a problem, but will retry til limit: #{e}")
    end
  end
end

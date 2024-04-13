# frozen_string_literal: true

module ::DiscourseChatbot
  class TopicEmbeddingsBookmark < ActiveRecord::Base
    self.table_name = 'chatbot_topic_embeddings_bookmark'

    validates :topic_id, presence: true
  end
end

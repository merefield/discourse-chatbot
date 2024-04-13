# frozen_string_literal: true

module ::DiscourseChatbot
  class TopicTitleEmbedding < ActiveRecord::Base
    self.table_name = 'chatbot_topic_title_embeddings'

    validates :topic_id, presence: true, uniqueness: true
  end
end

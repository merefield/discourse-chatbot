# frozen_string_literal: true

module ::DiscourseChatbot
  class PostEmbeddingsBookmark < ActiveRecord::Base
    self.table_name = 'chatbot_post_embeddings_bookmark'

    validates :post_id, presence: true
  end
end

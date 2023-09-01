# frozen_string_literal: true

module ::DiscourseChatbot

  class PostEmbeddingPgembedding < ActiveRecord::Base
    self.table_name = 'chatbot_post_embeddings'

    validates :post_id, presence: true, uniqueness: true
  end

end

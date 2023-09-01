# frozen_string_literal: true

class ::DiscourseChatbot::PostEmbeddingPgvector < ActiveRecord::Base
  self.table_name = 'chatbot_pgvector_post_embeddings'

  validates :post_id, presence: true, uniqueness: true
end

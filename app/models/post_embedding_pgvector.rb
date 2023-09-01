# frozen_string_literal: true

module ::DiscourseChatbot

  class PgvectorPostEmbedding < ActiveRecord::Base
    self.table_name = 'chatbot_pgvector_post_embeddings'

    validates :post_id, presence: true, uniqueness: true
  end

end

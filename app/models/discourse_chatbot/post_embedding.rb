# frozen_string_literal: true

module ::DiscourseChatbot
  class PostEmbedding < ActiveRecord::Base
    self.table_name = 'chatbot_post_embeddings'

    validates :post_id, presence: true, uniqueness: true
  end
end

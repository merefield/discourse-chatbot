# frozen_string_literal: true

class ::DiscourseChatbot::PostEmbedding < ActiveRecord::Base
  self.table_name = 'chatbot_post_embeddings'

  validates :post_id, presence: true, uniqueness: true
end

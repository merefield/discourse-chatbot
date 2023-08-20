# frozen_string_literal: true

class ::DiscourseChatbot::Embedding < ActiveRecord::Base
  self.table_name = 'chatbot_embeddings'

  validates :post_id, presence: true, uniqueness: true
end

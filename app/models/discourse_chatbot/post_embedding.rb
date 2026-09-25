# frozen_string_literal: true

module ::DiscourseChatbot
  class PostEmbedding < ActiveRecord::Base
    self.table_name = "chatbot_post_embeddings"

    validates :post_id, presence: true, uniqueness: true
  end
end

# == Schema Information
#
# Table name: chatbot_post_embeddings
#
#  id         :bigint           not null, primary key
#  embedding  :vector(1536)     not null
#  model      :string
#  provider   :string           default("open_ai"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer          not null
#
# Indexes
#
#  index_chatbot_post_embeddings_on_post_id   (post_id) UNIQUE
#  pgv_hnsw_index_on_chatbot_post_embeddings  (embedding vector_cosine_ops) USING hnsw
#

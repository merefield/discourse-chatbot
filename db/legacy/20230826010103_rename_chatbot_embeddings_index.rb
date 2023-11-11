# frozen_string_literal: true

class RenameChatbotEmbeddingsIndex < ActiveRecord::Migration[7.0]
  def change
    rename_index :chatbot_post_embeddings, 'hnsw_index_on_chatbot_embeddings', 'hnsw_index_on_chatbot_post_embeddings'
  end
end

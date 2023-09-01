# frozen_string_literal: true

class CreateChatbotPgvectorPostEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :chatbot_pgvector_post_embeddings do |t|
      t.integer :post_id, null: false, index: { unique: true }, foreign_key: true
        t.column :embedding, "vector(#{::DiscourseChatbot::EMBEDDING_DIMENSIONS})", null: false
        t.timestamps
    end
  end
end

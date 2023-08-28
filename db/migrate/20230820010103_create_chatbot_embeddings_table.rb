# frozen_string_literal: true

class CreateChatbotEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :chatbot_embeddings do |t|
      t.integer :post_id, null: false, index: { unique: true }, foreign_key: true
        t.column :embedding, "real[]", null: false
        t.timestamps
    end
  end
end

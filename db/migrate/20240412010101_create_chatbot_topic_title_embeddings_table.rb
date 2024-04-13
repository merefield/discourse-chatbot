# frozen_string_literal: true

class CreateChatbotTopicTitleEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :chatbot_topic_title_embeddings do |t|
      t.integer :topic_id, null: false, index: { unique: true }, foreign_key: true
      t.column :embedding, "vector(1536)", null: false
      t.column :model, :string, default: nil
      t.timestamps
    end
  end
end

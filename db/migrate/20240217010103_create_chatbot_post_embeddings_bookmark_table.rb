# frozen_string_literal: true

class CreateChatbotPostEmbeddingsBookmarkTable < ActiveRecord::Migration[7.0]
  def change
    create_table :chatbot_post_embeddings_bookmark do |t|
      t.integer :post_id
      t.timestamps
    end
  end
end

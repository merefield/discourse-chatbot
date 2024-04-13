# frozen_string_literal: true

class CreateChatbotTopicEmbeddingsBookmarkTable < ActiveRecord::Migration[7.0]
  def change
    create_table :chatbot_topic_embeddings_bookmark do |t|
      t.integer :topic_id
      t.timestamps
    end
  end
end

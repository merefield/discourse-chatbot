# frozen_string_literal: true
class AddModelColumnToChatbotPostEmbeddingsTable < ActiveRecord::Migration[5.2]
  def change
    add_column :chatbot_post_embeddings, :model, :string, default: nil
  end
end

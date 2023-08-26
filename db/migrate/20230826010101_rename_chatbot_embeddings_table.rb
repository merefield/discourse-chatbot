
# frozen_string_literal: true

class RenameChatbotEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    begin
      Migration::SafeMigrate.disable!
      rename_table :chatbot_embeddings, :chatbot_post_embeddings
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end

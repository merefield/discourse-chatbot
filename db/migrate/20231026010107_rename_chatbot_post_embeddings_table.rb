
# frozen_string_literal: true

class RenameChatbotPostEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    begin
      Migration::SafeMigrate.disable!
      rename_table :chatbot_post_embeddings, :chatbot_post_embeddings_old
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end

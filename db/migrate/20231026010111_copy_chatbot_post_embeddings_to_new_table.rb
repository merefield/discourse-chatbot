# frozen_string_literal: true

class CopyChatbotPostEmbeddingsToNewTable < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      INSERT INTO chatbot_post_embeddings (id, embedding)
      SELECT id, embedding::vector(1536) FROM chatbot_post_embeddings_old;
    SQL
  end

  def down
    ::DiscourseChatbot::PostEmbedding.delete_all
  end
end

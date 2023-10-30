# frozen_string_literal: true

class CopyChatbotPostEmbeddingsToNewTable < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      INSERT INTO chatbot_post_embeddings (id, post_id, embedding, created_at, updated_at)
      SELECT id, post_id, embedding::vector(1536), created_at, updated_at FROM chatbot_post_embeddings_old;
    SQL
    execute <<-SQL
      SELECT setval(pg_get_serial_sequence('chatbot_post_embeddings', 'id'), MAX(id)) FROM chatbot_post_embeddings;
    SQL
  end

  def down
    ::DiscourseChatbot::PostEmbedding.delete_all
  end
end

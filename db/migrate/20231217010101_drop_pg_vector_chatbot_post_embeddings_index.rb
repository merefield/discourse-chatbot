# frozen_string_literal: true

class DropPgVectorChatbotPostEmbeddingsIndex < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      DROP INDEX IF EXISTS pgv_hnsw_index_on_chatbot_post_embeddings;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

# frozen_string_literal: true

class CreateChatbotEmbeddingsIndex < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      CREATE INDEX hnsw_index_on_chatbot_embeddings ON chatbot_embeddings USING hnsw(embedding)
      WITH (dims=1536, m=64, efconstruction=64, efsearch=64);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX hnsw_index_on_chatbot_embeddings;
    SQL
  end
end

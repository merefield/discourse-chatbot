# frozen_string_literal: true

class CreateChatbotEmbeddingsIndex < ActiveRecord::Migration[7.0]
  def up
    begin
      execute <<-SQL
        CREATE INDEX hnsw_index_on_chatbot_embeddings ON chatbot_embeddings USING hnsw(embedding)
        WITH (dims=#{::DiscourseChatbot::EMBEDDING_DIMENSIONS}, m=64, efconstruction=64, efsearch=64);
      SQL
    rescue Exception => e
      STDERR.puts "---------------------------------DISCOURSE CHATBOT WARNING-----------------------------------------"
      STDERR.puts " Discourse Chatbot performs best with the pgembedding extension on the PostgreSQL database."
      STDERR.puts "                  See required changes to `app.yml` described at:"
      STDERR.puts "               https://github.com/merefield/discourse-chatbot/pull/33"
      STDERR.puts "      For now, Chatbot will fall back to the standard PG Vector extension instead."
      STDERR.puts "You can rerun these migrations in order later to add support once you resolve set-up as you see fit"
      STDERR.puts "----------------------------------DISCOURSE CHATBOT WARNING-----------------------------------------"
    end
  end

  def down
    execute <<-SQL
      DROP INDEX hnsw_index_on_chatbot_embeddings;
    SQL
  end
end

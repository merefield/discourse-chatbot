# frozen_string_literal: true

class RenameChatbotEmbeddingsIndex < ActiveRecord::Migration[7.0]
  def change
    begin
      rename_index :chatbot_post_embeddings, 'hnsw_index_on_chatbot_embeddings', 'hnsw_index_on_chatbot_post_embeddings'
    rescue
      STDERR.puts "---------------------------------DISCOURSE CHATBOT WARNING-----------------------------------------"
      STDERR.puts " Discourse Chatbot performs best with the pgembedding extension on the PostgreSQL database."
      STDERR.puts "                  See required changes to `app.yml` described at:"
      STDERR.puts "               https://github.com/merefield/discourse-chatbot/pull/33"
      STDERR.puts "      For now, Chatbot will fall back to the standard PG Vector extension instead."
      STDERR.puts "You can rerun these migrations in order later to add support once you resolve set-up as you see fit"
      STDERR.puts "----------------------------------DISCOURSE CHATBOT WARNING-----------------------------------------"
    end
  end
end

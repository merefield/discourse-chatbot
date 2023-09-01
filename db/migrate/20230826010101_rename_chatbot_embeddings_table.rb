
# frozen_string_literal: true

class RenameChatbotEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    begin
      Migration::SafeMigrate.disable!
      rename_table :chatbot_embeddings, :chatbot_post_embeddings
    rescue
      STDERR.puts "---------------------------------DISCOURSE CHATBOT WARNING-----------------------------------------"
      STDERR.puts " Discourse Chatbot performs best with the pgembedding extension on the PostgreSQL database."
      STDERR.puts "                  See required changes to `app.yml` described at:"
      STDERR.puts "               https://github.com/merefield/discourse-chatbot/pull/33"
      STDERR.puts "      For now, Chatbot will fall back to the standard PG Vector extension instead."
      STDERR.puts "You can rerun these migrations in order later to add support once you resolve set-up as you see fit"
      STDERR.puts "----------------------------------DISCOURSE CHATBOT WARNING-----------------------------------------"
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end

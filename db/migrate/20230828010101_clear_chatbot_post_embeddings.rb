# frozen_string_literal: true

class ClearChatbotPostEmbeddings < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM chatbot_post_embeddings"
    STDERR.puts "------------------------------DISCOURSE CHATBOT NOTICE----------------------------------"
    STDERR.puts "This version of Chatbot introduces improvements to the selection of Posts for embedding."
    STDERR.puts "         As such all existing chatbot post embeddings have been cleared out."
    STDERR.puts "   Please refresh them inside the container with `rake chatbot:refresh_embeddings[1]`"
    STDERR.puts "              Only necessary if you have selected bot type `agent`"
    STDERR.puts "------------------------------DISCOURSE CHATBOT NOTICE----------------------------------"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

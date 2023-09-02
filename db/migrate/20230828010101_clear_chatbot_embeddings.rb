# frozen_string_literal: true

class ClearChatbotEmbeddings < ActiveRecord::Migration[7.0]
  def up
    ::DiscourseChatbot::PostEmbedding.delete_all
    STDERR.puts "------------------------------DISCOURSE CHATBOT NOTICE----------------------------------"
    STDERR.puts "This version of Chatbot introduces improvements to the selection of Posts for embedding."
    STDERR.puts "         As such all existing chatbot post embeddings have been cleared out."
    STDERR.puts "   Please refresh them inside the container with `rake chatbot:refresh_embeddings[1]`"
    STDERR.puts "              Only necessary if you have selected bot type `agent`"
    STDERR.puts "------------------------------DISCOURSE CHATBOT NOTICE----------------------------------"
  end
end

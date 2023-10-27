# frozen_string_literal: true

class EnableEmbeddingExtension < ActiveRecord::Migration[7.0]
  def change
    begin
      enable_extension :embedding, if_exists: true
    rescue Exception => e
      STDERR.puts "----------------------------DISCOURSE CHATBOT ERROR----------------------------------"
      STDERR.puts " Discourse Chatbot now requires the embedding extension on the PostgreSQL database."
      STDERR.puts "                  See required changes to `app.yml` described at:"
      STDERR.puts "              https://github.com/merefield/discourse-chatbot/pull/33"
      STDERR.puts "            Alternatively, you can remove Discourse Chatbot to rebuild."
      STDERR.puts "----------------------------DISCOURSE CHATBOT ERROR----------------------------------"
      raise e
    end
  end
end

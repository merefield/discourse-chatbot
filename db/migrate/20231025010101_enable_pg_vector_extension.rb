# frozen_string_literal: true

class EnablePgVectorExtension < ActiveRecord::Migration[7.0]
  def change
    begin
      enable_extension :vector
    rescue Exception => e
      if DB.query_single("SELECT 1 FROM pg_available_extensions WHERE name = 'vector';").empty?
        STDERR.puts "----------------------------------DISCOURSE CHATBOT ERROR----------------------------------------"
        STDERR.puts "  Discourse Chatbot now requires the pgvector extension version 0.5.1 on the PostgreSQL database."
        STDERR.puts "         Run a `./launcher rebuild app` to fix it on a standard install."
        STDERR.puts "            Alternatively, you can remove Discourse Chatbot to rebuild."
        STDERR.puts "----------------------------------DISCOURSE CHATBOT ERROR----------------------------------------"
      end
      raise e
    end
  end
end
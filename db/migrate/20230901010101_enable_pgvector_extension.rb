# frozen_string_literal: true
class EnablePgvectorExtension < ActiveRecord::Migration[7.0]
  def change
    begin
      enable_extension :vector
    rescue Exception => e
      STDERR.puts "------------------------------DISCOURSE CHATBOT ERROR ----------------------------------"
      STDERR.puts "Discourse Chatbot relies on pgvector extension as fallback on the PostgreSQL database."
      STDERR.puts "         Run a `./launcher rebuild app` to fix it on a standard install."
      STDERR.puts "            Alternatively, you can remove Discourse Chatbot to rebuild."
      STDERR.puts "------------------------------DISCOURSE CHATBOT ERROR ----------------------------------"
      raise e
    end
  end
end

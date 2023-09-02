# frozen_string_literal: true

class ClearChatbotEmbeddings < ActiveRecord::Migration[7.0]
  def up
    ::DiscourseChatbot::PostEmbedding.delete_all
  end
end

# frozen_string_literal: true
class AddProviderToChatbotEmbeddings < ActiveRecord::Migration[8.0]
  def change
    add_column :chatbot_post_embeddings, :provider, :string, default: "open_ai", null: false
    add_column :chatbot_topic_title_embeddings, :provider, :string, default: "open_ai", null: false
  end
end

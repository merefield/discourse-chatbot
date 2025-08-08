# frozen_string_literal: true

class CreateChatbotTokenUsageTable < ActiveRecord::Migration[7.0]
  def change
    create_table :chatbot_token_usage do |t|
      t.integer :user_id, null: false
      t.string :model_name, null: false
      t.string :request_type, null: false  # 'chat', 'embedding', 'vision', 'image_generation'
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.integer :total_tokens, null: false
      t.decimal :input_cost, precision: 10, scale: 6, default: 0.0
      t.decimal :output_cost, precision: 10, scale: 6, default: 0.0
      t.decimal :total_cost, precision: 10, scale: 6, null: false
      t.string :currency, default: 'USD'
      t.text :metadata, null: true  # JSON field for additional data
      t.integer :topic_id, null: true
      t.integer :post_id, null: true
      t.integer :chat_message_id, null: true
      t.timestamps
    end

    add_index :chatbot_token_usage, :user_id
    add_index :chatbot_token_usage, :model_name
    add_index :chatbot_token_usage, :request_type
    add_index :chatbot_token_usage, :created_at
    add_index :chatbot_token_usage, [:user_id, :created_at]
    add_index :chatbot_token_usage, [:model_name, :created_at]
  end
end

# frozen_string_literal: true
DiscourseChatbot::Engine.routes.draw do
  post '/start_bot_convo' => 'chatbot#start_bot_convo'
  
  # Admin routes for token statistics
  scope '/admin', constraints: StaffConstraint.new do
    get '/token-stats' => 'chatbot_token_stats#index'
    get '/token-stats/usage' => 'chatbot_token_stats#usage_stats'
    get '/token-stats/models' => 'chatbot_token_stats#model_stats'
    get '/token-stats/users' => 'chatbot_token_stats#user_stats'
    get '/token-stats/export' => 'chatbot_token_stats#export_data'
    delete '/token-stats/cleanup' => 'chatbot_token_stats#cleanup_old_data'
  end
end

Discourse::Application.routes.draw do
  mount ::DiscourseChatbot::Engine, at: 'chatbot'
end

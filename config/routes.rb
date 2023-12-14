# frozen_string_literal: true
::DiscourseChatbot::Engine.routes.draw do
  post '/start_bot_convo' => 'chatbot#start_bot_convo'
end

Discourse::Application.routes.draw do
  mount ::DiscourseChatbot::Engine, at: 'chatbot'
end

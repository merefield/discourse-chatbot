# frozen_string_literal: true
DiscourseChatbot::Engine.routes.draw { post "/start_bot_convo" => "chatbot#start_bot_convo" }

Discourse::Application.routes.draw { mount ::DiscourseChatbot::Engine, at: "chatbot" }

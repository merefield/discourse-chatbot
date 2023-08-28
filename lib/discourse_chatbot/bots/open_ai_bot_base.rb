# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBotBase < Bot
    def initialize
      ::OpenAI.configure do |config|
        config.access_token = SiteSetting.chatbot_open_ai_token
      end
      if !SiteSetting.chatbot_open_ai_model_custom_url.blank?
        ::OpenAI.configure do |config|
          config.uri_base = SiteSetting.chatbot_open_ai_model_custom_url
        end
      end
      if SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
        ::OpenAI.configure do |config|
          config.api_type = :azure
          config.api_version = SiteSetting.chatbot_open_ai_model_custom_api_version
        end
      end
      @client = ::OpenAI::Client.new
      @model_name = SiteSetting.chatbot_open_ai_model_custom ? SiteSetting.chatbot_open_ai_model_custom_name : SiteSetting.chatbot_open_ai_model
    end

    def get_response(prompt)
      raise "Overwrite me!"
    end

  end
end

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAiBotBase < Bot
    def initialize
      if SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
        ::OpenAI.configure do |config|
          config.access_token = SiteSetting.chatbot_open_ai_token
          config.uri_base = SiteSetting.chatbot_open_ai_model_custom_url
          config.api_type = :azure
          config.api_version = SiteSetting.chatbot_open_ai_model_custom_api_version
        end
      else
        if !SiteSetting.chatbot_open_ai_model_custom_url.blank?
          ::OpenAI.configure do |config|
            config.access_token = SiteSetting.chatbot_open_ai_token
            config.uri_base = SiteSetting.chatbot_open_ai_model_custom_url
          end
          @client = ::OpenAI::Client.new
        else
          @client = ::OpenAI::Client.new(access_token: SiteSetting.chatbot_open_ai_token)
        end
      end

      @model_name = SiteSetting.chatbot_open_ai_model_custom ? SiteSetting.chatbot_open_ai_model_custom_name : SiteSetting.chatbot_open_ai_model
    end

    def get_response(prompt)
      raise "Overwrite me!"
    end

  end
end

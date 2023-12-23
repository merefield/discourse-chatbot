# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBotBase < Bot
    def initialize(opts)
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
      @client = OpenAI::Client.new do |f|
        f.response :logger, Logger.new($stdout), bodies: true if SiteSetting.chatbot_enable_verbose_console_logging
        f.response :logger, Rails.logger, bodies: true if SiteSetting.chatbot_enable_verbose_rails_logging
      end
      @model_name = SiteSetting.chatbot_open_ai_model_custom ? SiteSetting.chatbot_open_ai_model_custom_name : SiteSetting.chatbot_open_ai_model
    end

    def get_response(prompt, opts)
      raise "Overwrite me!"
    end

  end
end

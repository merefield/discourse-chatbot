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
      @model_name =
        case opts[:trust_level]
        when nil
          SiteSetting.chatbot_open_ai_model_custom_low_trust ? SiteSetting.chatbot_open_ai_model_custom_name_low_trust : SiteSetting.chatbot_open_ai_model_low_trust
        when TRUST_LEVELS[0], TRUST_LEVELS[1], TRUST_LEVELS[2]
          SiteSetting.send("chatbot_open_ai_model_custom_" + opts[:trust_level] + "_trust") ? 
            SiteSetting.send("chatbot_open_ai_model_custom_name_" + opts[:trust_level] + "_trust") :
            SiteSetting.send("chatbot_open_ai_model_" + opts[:trust_level] + "_trust")
        else
          SiteSetting.chatbot_open_ai_model_custom_low_trust ? SiteSetting.chatbot_open_ai_model_custom_name_low_trust : SiteSetting.chatbot_open_ai_model_low_trust
        end
    end

    def get_response(prompt, opts)
      raise "Overwrite me!"
    end

  end
end

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBotBase < Bot

    def initialize(opts)
      ::OpenAI.configure do |config|
        config.access_token = SiteSetting.chatbot_open_ai_token

        case opts[:trust_level] 
        when TRUST_LEVELS[0], TRUST_LEVELS[1], TRUST_LEVELS[2]
          if !SiteSetting.send("chatbot_open_ai_model_custom_url_" + opts[:trust_level] + "_trust").blank?
            config.uri_base = SiteSetting.send("chatbot_open_ai_model_custom_url_" + opts[:trust_level] + "_trust")
          end
        else
          if !SiteSetting.chatbot_open_ai_model_custom_url_low_trust.blank?
            config.uri_base = SiteSetting.chatbot_open_ai_model_custom_url_low_trust
          end
        end

        if SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
          config.api_type = :azure
          config.api_version = SiteSetting.chatbot_open_ai_model_custom_api_version
        end
        config.log_errors = true if SiteSetting.chatbot_enable_verbose_rails_logging
      end

      @client = OpenAI::Client.new do |f|
        f.response :logger, Logger.new($stdout), bodies: true if SiteSetting.chatbot_enable_verbose_console_logging
        if SiteSetting.chatbot_enable_verbose_rails_logging != "off"
          case SiteSetting.chatbot_verbose_rails_logging_destination
            when "warn"
              f.response :logger, Rails.logger, bodies: true, log_level: :warn
            else
              f.response :logger, Rails.logger, bodies: true, log_level: :info
          end
        end
      end

      @model_name =
        SiteSetting.chatbot_support_vision == "directly" ? SiteSetting.chatbot_open_ai_vision_model :
          case opts[:trust_level]
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

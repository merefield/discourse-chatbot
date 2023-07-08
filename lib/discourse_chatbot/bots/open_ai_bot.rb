# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBot < Bot

    def initialize
      if SiteSetting.chatbot_open_ai_model.include?("gpt-3.5") &&
        SiteSetting.chatbot_openai_gpt35_url.include?("azure")
        ::OpenAI.configure do |config|
          config.access_token = SiteSetting.chatbot_open_ai_token
          config.uri_base = SiteSetting.chatbot_openai_gpt35_url
          config.api_type = :azure
          config.api_version = "2023-05-15"
        end
        @client = ::OpenAI::Client.new
      elsif SiteSetting.chatbot_open_ai_model.include?("gpt-4") &&
        SiteSetting.chatbot_openai_gpt4_url.include?("azure")
        ::OpenAI.configure do |config|
          config.access_token = SiteSetting.chatbot_open_ai_token
          config.uri_base = SiteSetting.chatbot_openai_gpt4_url
          config.api_type = :azure
          config.api_version = "2023-05-15"
        end
        @client = ::OpenAI::Client.new
      else
        @client = ::OpenAI::Client.new(access_token: SiteSetting.chatbot_open_ai_token)
      end
    end

    def get_response(prompt)

      model_name = SiteSetting.chatbot_open_ai_model_custom ? SiteSetting.chatbot_open_ai_model_custom_name : SiteSetting.chatbot_open_ai_model

      if ["gpt-3.5-turbo", "gpt-3.5-turbo-16k", "gpt-4", "gpt-4-32k"].include?(SiteSetting.chatbot_open_ai_model) ||
        (SiteSetting.chatbot_open_ai_model_custom == true && SiteSetting.chatbot_open_ai_model_custom_type == "chat")
        response = @client.chat(
          parameters: {
            model: model_name,
            messages: prompt,
            max_tokens: SiteSetting.chatbot_max_response_tokens,
            temperature: SiteSetting.chatbot_request_temperature / 100.0,
            top_p: SiteSetting.chatbot_request_top_p / 100.0,
            frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
            presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0
          })

        if response["error"]
          begin
            raise StandardError, response["error"]["message"]
          rescue => e
            Rails.logger.error("OpenAIBot: There was a problem: #{e}")
            I18n.t('chatbot.errors.general')
          end
        else
          response.dig("choices", 0, "message", "content")
        end
      elsif (SiteSetting.chatbot_open_ai_model_custom == true && SiteSetting.chatbot_open_ai_model_custom_type == "completions") ||
        ["text-davinci-003", "text-davinci-002"].include?(SiteSetting.chatbot_open_ai_model)

        response = @client.completions(
          parameters: {
            model: SiteSetting.chatbot_open_ai_model,
            prompt: prompt,
            max_tokens: SiteSetting.chatbot_max_response_tokens,
            temperature: SiteSetting.chatbot_request_temperature / 100.0,
            top_p: SiteSetting.chatbot_request_top_p / 100.0,
            frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
            presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0
          })

        if response["error"]
          begin
            raise StandardError, response["error"]["message"]
          rescue => e
            Rails.logger.error("OpenAIBot: There was a problem: #{e}")
            I18n.t('chatbot.errors.general')
          end
        else
          response["choices"][0]["text"]
        end
      end
    end

    def ask(opts)
      super(opts)
    end
  end
end

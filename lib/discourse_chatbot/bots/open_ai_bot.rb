# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBot < Bot

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
    end

    def get_response(prompt)
      system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.basic") }
      prompt.unshift(system_message)

      model_name = SiteSetting.chatbot_open_ai_model_custom ? SiteSetting.chatbot_open_ai_model_custom_name : SiteSetting.chatbot_open_ai_model

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
    end

    def ask(opts)
      super(opts)
    end
  end
end

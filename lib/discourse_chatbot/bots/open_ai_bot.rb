# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBot < Bot

    def initialize
      super
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

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBot < Bot

    def initialize

      # TODO add this in when support added via PR after "ruby-openai", '3.3.0'
      # OpenAI.configure do |config|
      #   config.request_timeout = 25
      # end

      @client = ::OpenAI::Client.new(access_token: SiteSetting.chatbot_open_ai_token)

    end

    def get_response(prompt)
      if SiteSetting.chatbot_open_ai_model == "gpt-3.5-turbo"
        response = @client.chat(
          parameters: {
              model: "gpt-3.5-turbo",
              messages: prompt,
              temperature: SiteSetting.chatbot_request_temperature / 100.0
          })

        if response.parsed_response["error"]
          raise StandardError, response.parsed_response["error"]["message"]
        rescue => e
          Rails.logger.error ("OpenAIBot: There was a problem: #{e}")
          I18n.t('chatbot.errors.general')
        else
          response.dig("choices", 0, "message", "content")
        end
      else
        response = @client.completions(
          parameters: {
              model: SiteSetting.chatbot_open_ai_model,
              prompt: prompt,
              max_tokens: SiteSetting.chatbot_max_response_tokens,
              temperature: SiteSetting.chatbot_request_temperature / 100.0
          })

        if response.parsed_response["error"]
          raise StandardError, response.parsed_response["error"]["message"]
        rescue => e
          Rails.logger.error ("OpenAIBot: There was a problem: #{e}")
          I18n.t('chatbot.errors.general')
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

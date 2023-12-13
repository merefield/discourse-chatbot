# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAiBotBasic < OpenAIBotBase

    def initialize
      super
    end

    def get_response(prompt, private_discussion = false)
      if private_discussion
        system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.private.basic", current_date_time: DateTime.current) }
      else
        system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.open.basic", current_date_time: DateTime.current) }
      end

      prompt.unshift(system_message)

      response = @client.chat(
        parameters: {
          model: @model_name,
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
          Rails.logger.error("Chatbot: There was a problem: #{e}")
          {
            reply: I18n.t('chatbot.errors.general'),
            inner_thoughts: nil
          }
        end
      else
        {
          reply: response.dig("choices", 0, "message", "content"),
          inner_thoughts: nil
        }
      end
    end

    def ask(opts)
      super(opts)
    end
  end
end

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAiBotBasic < OpenAIBotBase

    def get_response(prompt, opts)
      begin
        reasoning_model = false
        private_discussion = opts[:private] || false

        if private_discussion
          system_message = { "role": "developer", "content": I18n.t("chatbot.prompt.system.basic.private", current_date_time: DateTime.current) }
        else
          system_message = { "role": "developer", "content": I18n.t("chatbot.prompt.system.basic.open", current_date_time: DateTime.current) }
        end

        reasoning_model = true if REASONING_MODELS.include?(@model_name)

        prompt.unshift(system_message)

        parameters = {
          model: @model_name,
          messages: prompt,
          max_completion_tokens: SiteSetting.chatbot_max_response_tokens,
        }

        additional_non_reasoning_parameters = {
          temperature: SiteSetting.chatbot_request_temperature / 100.0,
          top_p: SiteSetting.chatbot_request_top_p / 100.0,
          frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
          presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0
        }

        additional_reasoning_parameters = {
          reasoning_effort: @model_reasoning_level,
        }

        if reasoning_model
          parameters.merge!(additional_reasoning_parameters)
        else
          parameters.merge!(additional_non_reasoning_parameters)
        end

        response = @client.chat(
          parameters: parameters
        )

        token_usage = response.dig("usage", "total_tokens")
        @total_tokens += token_usage

        {
          reply: response.dig("choices", 0, "message", "content"),
          inner_thoughts: nil
        }
      rescue => e
        if e.respond_to?(:response)
          status = e.response[:status]
          message = e.response[:body]["error"]["message"]
          Rails.logger.error("Chatbot: There was a problem with Chat Completion: status: #{status}, message: #{message}")
        end
        raise e
      end
    end
  end
end

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIBot < Bot

    def initialize
     
      # TODO add this in when support added via PR after "ruby-openai", '3.3.0'
      # OpenAI.configure do |config|
      #   config.request_timeout = 25
      # end

      # TODO consider other bot parameters
      # , params: {key: chatbot_api_key, cb_settings_tweak1: wackiness, cb_settings_tweak2: talkativeness, cb_settings_tweak3: attentiveness})
  
      @client = ::OpenAI::Client.new(access_token: SiteSetting.chatbot_open_ai_token)

    end

    def get_response(prompt)
      if SiteSetting.chatbot_open_ai_model == "gpt-3.5-turbo"
        # puts prompt.count
        # puts prompt
        # puts prompt.kind_of?(Array)
        response = @client.chat(
          parameters: {
              model: "gpt-3.5-turbo",
              messages: prompt
          })

          final_text = response.dig("choices", 0, "message", "content")
      else
        response = @client.completions(
          parameters: {
              model: SiteSetting.chatbot_open_ai_model,
              prompt: prompt,
              max_tokens: SiteSetting.chatbot_max_response_tokens
          })

        if response.parsed_response["error"]
          raise StandardError, response.parsed_response["error"]["message"]
        end

        final_text = response["choices"][0]["text"]
      end
    end

    def ask(opts)
      super(opts)
    end
  end
end

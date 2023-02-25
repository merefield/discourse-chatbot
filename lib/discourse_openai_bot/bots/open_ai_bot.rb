# frozen_string_literal: true
require "openai"

module ::DiscourseOpenAIBot

  class OpenAIBot < Bot

    def initialize
     
      # TODO add this in when support added via PR after "ruby-openai", '3.3.0'
      # OpenAI.configure do |config|
      #   config.request_timeout = 25
      # end

      # TODO consider other bot parameters
      # , params: {key: openai_bot_api_key, cb_settings_tweak1: wackiness, cb_settings_tweak2: talkativeness, cb_settings_tweak3: attentiveness})
  
      @client = ::OpenAI::Client.new(access_token: SiteSetting.openai_bot_open_ai_token)

    end


    def get_response(prompt)
      response = @client.completions(
        parameters: {
            model: SiteSetting.openai_bot_open_ai_model,
            prompt: "#{prompt}",
            max_tokens: SiteSetting.openai_bot_max_response_tokens
        })
  
      if response.parsed_response["error"]
        raise StandardError, response.parsed_response["error"]["message"]
      end
  
      final_text = response["choices"][0]["text"]
    end


    def ask(opts)
      super(opts)
    end
  end
end

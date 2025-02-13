# frozen_string_literal: true

require_relative '../function'
require "google_search_results"

module DiscourseChatbot
  class WebSearchFunction < Function

    def name
      'web_search'
    end

    def description
      I18n.t("chatbot.prompt.function.web_search.description")
    end

    def parameters
      [
        { name: "query", type: String, description:  I18n.t("chatbot.prompt.function.web_search.parameters.query") } ,
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        super(args)
        token_usage = 0
        if SiteSetting.chatbot_serp_api_key.blank?
          query = URI.encode_www_form_component(args[parameters[0][:name]])
          conn = Faraday.new(
            url: "https://s.jina.ai/#{query}",
            headers: {
              "Authorization" => "Bearer #{SiteSetting.chatbot_jina_api_token}"
            }
          )
          response = conn.get
          result = response.body
          token_usage =  response.body.length * SiteSetting.chatbot_jina_api_token_cost_multiplier
        else
          hash_results = ::GoogleSearch.new(q: args[parameters[0][:name]], serp_api_key: SiteSetting.chatbot_serp_api_key)
            .get_hash

          result = hash_results.dig(:answer_box, :answer).presence ||
          hash_results.dig(:answer_box, :snippet).presence ||
          hash_results.dig(:organic_results)
          token_usage = SiteSetting.chatbot_serp_api_token_cost
        end
        {
          answer: result[0..SiteSetting.chatbot_function_response_char_limit],
          token_usage: token_usage
        }
      rescue => e
        Rails.logger.error("Chatbot: Error in web_search function: #{e}")
        {
          answer: I18n.t("chatbot.prompt.function.web_search.error", query: args[parameters[0][:name]]),
          token_usage: 0
        }
      end
    end
  end
end

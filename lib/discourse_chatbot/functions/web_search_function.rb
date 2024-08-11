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
        else
          hash_results = ::GoogleSearch.new(q: args[parameters[0][:name]], serp_api_key: SiteSetting.chatbot_serp_api_key)
            .get_hash

          hash_results.dig(:answer_box, :answer) ||
          hash_results.dig(:answer_box, :snippet) ||
          result = hash_results.dig(:organic_results, 0, :snippet)
        end
        result[0..SiteSetting.chatbot_function_response_char_limit]
      rescue
        I18n.t("chatbot.prompt.function.web_search.error", query: args[parameters[0][:name]])
      end
    end
  end
end

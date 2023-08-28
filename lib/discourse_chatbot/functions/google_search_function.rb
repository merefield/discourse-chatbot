# frozen_string_literal: true

require_relative '../function'
require "google_search_results"

module DiscourseChatbot
  class GoogleSearchFunction < Function

    def name
      'google_search'
    end

    def description
      I18n.t("chatbot.prompt.function.google_search.description")
    end

    def parameters
      [
        { name: "query", type: String, description:  I18n.t("chatbot.prompt.function.google_search.parameters.query") } ,
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        super(args)

        hash_results = ::GoogleSearch.new(q: args[parameters[0][:name]], serp_api_key: SiteSetting.chatbot_serp_api_key)
          .get_hash

        hash_results.dig(:answer_box, :answer) ||
        hash_results.dig(:answer_box, :snippet) ||
        hash_results.dig(:organic_results, 0, :snippet)
      rescue
        I18n.t("chatbot.prompt.function.google_search.error", query: args[parameters[0][:name]])
      end
    end
  end
end

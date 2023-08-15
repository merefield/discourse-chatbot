# frozen_string_literal: true

require_relative '../function'
require 'eqn'

module DiscourseChatbot
  class GoogleSearchFunction < Function

    def name
      'google_search'
    end

    def description
      <<~EOS 
        A wrapper around Google Search.

        Useful for when you need to answer questions about current events.
        Always one of the first options when you need to find information on internet.

        Input should be a search query.
      EOS
    end
    
    def parameters
      [
        { name: "query", type: String, description: "search query for looking up information on the internet" } ,
      ]
    end 

    def process(*args)
      begin
        super(*args)
        hash_results = ::GoogleSearch.new(q: args[0], serp_api_key: SiteSetting.chatbot_serp_api_key)
        .get_hash

        hash_results.dig(:answer_box, :answer) ||
        hash_results.dig(:answer_box, :snippet) ||
        hash_results.dig(:organic_results, 0, :snippet)
      rescue 
        "\"#{input}\": my search for this on the internet failed."
      end
    end
  end
end

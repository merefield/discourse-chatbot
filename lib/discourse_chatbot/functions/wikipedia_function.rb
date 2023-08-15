# frozen_string_literal: true

require_relative '../function'
require 'wikipedia-client'

module DiscourseChatbot
  
  class WikipediaFunction < Function
    
    def name
      'wikipedia'
    end

    def description
      <<~EOS
        A wrapper around Wikipedia.

        Useful for when you need to answer general questions about
        people, places, companies, facts, historical events, or other subjects.

        Input should be a search query
      EOS
    end

    def parameters
      [
       { name: 'query', type: String, description: "query string for wikipedia search" }
      ]
    end

    def process(*args)

      begin
        page = ::Wikipedia.find(args[0])

        page.summary
      rescue
        "ERROR: Had trouble retrieving information from wikipedia!"
      end
    end
  end
end
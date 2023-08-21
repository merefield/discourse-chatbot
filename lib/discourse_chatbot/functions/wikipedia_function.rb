# frozen_string_literal: true

require_relative '../function'
require 'wikipedia-client'

module DiscourseChatbot

  class WikipediaFunction < Function

    def name
      'wikipedia'
    end

    def description
      I18n.t("chatbot.prompt.function.wikipedia.description")
    end

    def parameters
      [
       { name: 'query', type: String, description: I18n.t("chatbot.prompt.function.wikipedia.parameters.query") }
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        super(args)

        page = ::Wikipedia.find(args[parameters[0][:name]])

        page.summary
      rescue
        I18n.t("chatbot.prompt.function.wikipedia.error")
      end
    end
  end
end

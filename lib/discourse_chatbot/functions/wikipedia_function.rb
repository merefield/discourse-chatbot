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

        {
          answer: I18n.t("chatbot.prompt.function.wikipedia.answer", summary: page.summary, url: page.fullurl),
          token_usage: 0
        }
      rescue
        {
          answer: I18n.t("chatbot.prompt.function.wikipedia.error"),
          token_usage: 0
        }
      end
    end
  end
end

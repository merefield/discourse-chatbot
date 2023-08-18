# frozen_string_literal: true

require_relative '../function'
require 'news-api'

module DiscourseChatbot
  class NewsFunction < Function

    def name
      'news'
    end

    def description
      <<~EOS
        A wrapper around the News API.

        Useful for when you need to answer questions about current events in the news, current events or affairs

        Input should be a search query and a date from which to search news, so if the request is today, the search should be for todays date'
      EOS
    end

    def parameters
      [
        { name: 'query', type: String, description: "query string for searching current news and events" },
        { name: 'start_date', type: String, description: "start date from which to search for news in format YYYY-MM-DD" }
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        ::DiscourseChatbot.progress_debug_message <<~EOS
        -------------------------------------
        arguments for news: #{args[parameters[0][:name]]}, #{args[parameters[1][:name]]}
        --------------------------------------
        EOS
        super(args)

        newsapi = News.new(SiteSetting.chatbot_news_api_token)
        all_articles = newsapi.get_everything(q: args[parameters[0][:name]],
                                              from: args[parameters[1][:name]], #'2023-08-01'
                                              language: 'en',
                                              sortBy: 'relevancy')
        news = "The latest news about this is: "
        all_articles.each do |a|
          news += "#{a.title}.  "
        end
        news
      rescue
        "ERROR: Had trouble retrieving the news!"
      end
    end
  end
end

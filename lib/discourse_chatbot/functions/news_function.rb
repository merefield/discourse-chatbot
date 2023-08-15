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
 
        Input should be a search query'
      EOS
    end

    def parameters
      [
        { name: 'query', type: String, description: "query string for searching current news and events" }
      ]
    end

    def process(*args)
      begin
        newsapi = News.new(SiteSetting.chatbot_news_api_token) #("125df0e20a6a44af924177715d64de61")   
        all_articles = newsapi.get_everything(q: args[0],
                                          from: '2023-08-01',
                                          language: 'en',
                                          sortBy: 'relevancy')
        #pp all_articles
        news = "The latest news about this is: "
        all_articles.each do |a|
          news += "#{a.title}.  "
        end
        #pp news
        news
      rescue
        "ERROR: Had trouble retrieving the news!"
      end
    end
  end
end

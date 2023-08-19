# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class NewsFunction < Function

    def name
      'news'
    end

    def description
      <<~EOS
        A wrapper around the News API.

        Useful for when you need to answer questions about current events in the news, current events or affairs.

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

        conn_params = {}

        conn_params = args[parameters[1][:name]].blank? ?
          { q: "#{args[parameters[0][:name]]}", language: 'en', sortBy: 'relevancy' } :
          { q: "#{args[parameters[0][:name]]}", language: 'en', sortBy: 'relevancy', start_date: "#{args[parameters[1][:name]]}" }

        conn = Faraday.new(
          url: 'https://newsapi.org',
          params: conn_params,
          headers: { 'X-Api-Key' => "#{SiteSetting.chatbot_news_api_token}" }
        )

        response = conn.get('/v2/everything')

        response_body = JSON.parse(response.body)

        all_articles = response_body["articles"]

        news = "The latest news about this is: "
        all_articles.each do |a|
          news += "#{a["title"]}.  "
        end
        news
      rescue
        "ERROR: Had trouble retrieving the news!"
      end
    end
  end
end

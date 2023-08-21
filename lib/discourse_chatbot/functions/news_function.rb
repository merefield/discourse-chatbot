# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class NewsFunction < Function

    def name
      'news'
    end

    def description
      I18n.t("chatbot.prompt.function.news.description")
    end

    def parameters
      [
        { name: 'query', type: String, description: I18n.t("chatbot.prompt.function.news.parameters.query") },
        { name: 'start_date', type: String, description: I18n.t("chatbot.prompt.function.news.parameters.start_date") }
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

        news = I18n.t("chatbot.prompt.function.news.answer")
        all_articles.each do |a|
          news += "#{a["title"]}.  "
        end
        news
      rescue
        I18n.t("chatbot.prompt.function.news.error")
      end
    end
  end
end

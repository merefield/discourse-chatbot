# frozen_string_literal: true

module DiscourseChatbot
  module Tools
    class News < ::DiscourseChatbot::Tool
      def name
        "news"
      end

      def description
        I18n.t("chatbot.prompt.function.news.description")
      end

      def parameters
        [
          {
            name: "query",
            type: String,
            description: I18n.t("chatbot.prompt.function.news.parameters.query"),
          },
          {
            name: "start_date",
            type: String,
            description: I18n.t("chatbot.prompt.function.news.parameters.start_date"),
          },
        ]
      end

      def required
        ["query"]
      end

      def process(args)
        begin
          ::DiscourseChatbot.progress_debug_message <<~EOS
        -------------------------------------
        arguments for news: #{args[parameters[0][:name]]}, #{args[parameters[1][:name]]}
        --------------------------------------
        EOS
          super(args)
          token_usage = 0

          conn_params = {}

          conn_params =
            (
              if args[parameters[1][:name]].blank?
                { q: "#{args[parameters[0][:name]]}", language: "en", sortBy: "relevancy" }
              else
                {
                  q: "#{args[parameters[0][:name]]}",
                  language: "en",
                  sortBy: "relevancy",
                  start_date: "#{args[parameters[1][:name]]}",
                }
              end
            )

          conn =
            Faraday.new(
              url: "https://newsapi.org",
              params: conn_params,
              headers: {
                "X-Api-Key" => "#{SiteSetting.chatbot_news_api_token}",
              },
            )

          response = conn.get("/v2/everything")

          response_body = JSON.parse(response.body)

          all_articles = response_body["articles"]

          news = I18n.t("chatbot.prompt.function.news.answer")
          all_articles.each { |a| news += "#{a["title"]}.  " }
          token_usage = SiteSetting.chatbot_news_api_call_token_cost
          { answer: news, token_usage: token_usage }
        rescue StandardError
          { answer: I18n.t("chatbot.prompt.function.news.error"), token_usage: token_usage }
        end
      end
    end
  end
end

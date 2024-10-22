# frozen_string_literal: true

require_relative '../function'
# require 'basic_yahoo_finance'

require 'net/http'
require 'json'

module DiscourseChatbot

  class StockDataFunction < Function

    def name
      'stock_data'
    end

    def description
      I18n.t("chatbot.prompt.function.stock_data.description")
    end

    def parameters
      [
       { name: 'ticker', type: String, description: I18n.t("chatbot.prompt.function.stock_data.parameters.ticker") },
       { name: 'date', type: String, description: I18n.t("chatbot.prompt.function.stock_data.parameters.date") }
      ]
    end

    def required
      ['ticker']
    end

    def process(args)
      begin
        super(args)
        token_usage = 0

        params = {
          access_key: "#{SiteSetting.chatbot_marketstack_key}",
          search: "#{CGI.escape(args[parameters[0][:name]])}"
        }
        uri = URI("http://api.marketstack.com/v1/tickers?")

        uri.query = URI.encode_www_form(params)
        json = Net::HTTP.get(uri)
        api_response = JSON.parse(json)

        ticker = api_response['data'][0]['symbol']
        uri = args[parameters[1][:name]].blank? ? URI("http://api.marketstack.com/v1/eod/latest") : URI("http://api.marketstack.com/v1/eod/#{args[parameters[1][:name]]}")

        params = {
          access_key: "#{SiteSetting.chatbot_marketstack_key}",
          symbols: "#{ticker}"
        }

        uri.query = URI.encode_www_form(params)
        json = Net::HTTP.get(uri)
        api_response = JSON.parse(json)

        stock_data = api_response['data'][0]
        token_usage = SiteSetting.chatbot_marketstack_api_call_token_cost

        {
          answer: I18n.t("chatbot.prompt.function.stock_data.answer", ticker: stock_data['symbol'], close: stock_data['close'].to_s, date: stock_data['date'].to_s, high: stock_data['high'].to_s, low: stock_data['low'].to_s),
          token_usage: token_usage
        }
      rescue
        {
          answer: I18n.t("chatbot.prompt.function.stock_data.error"),
          token_usage: token_usage
        }
      end
    end
  end
end

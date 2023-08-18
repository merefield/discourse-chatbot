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
      <<~EOS
        An API for MarketStack stock data

        You need to call it using the stock ticker.#{'  '}
      EOS
    end

    def parameters
      [
       { name: 'ticker', type: String, description: "ticker for share or stock query" },
      ]
    end

    def required
      ['ticker']
    end

    def process(args)
      begin
        super(args)

        params = {
          access_key: "#{SiteSetting.chatbot_marketstack_key}",
          search: "#{CGI.escape(args[parameters[0][:name]])}"
        }
        uri = URI("http://api.marketstack.com/v1/tickers?")

        uri.query = URI.encode_www_form(params)
        json = Net::HTTP.get(uri)
        api_response = JSON.parse(json)

        ticker = api_response['data'][0]['symbol']

        uri = URI("http://api.marketstack.com/v1/eod/latest")

        params = {
          access_key: "#{SiteSetting.chatbot_marketstack_key}",
          symbols: "#{ticker}"
        }

        uri.query = URI.encode_www_form(params)
        json = Net::HTTP.get(uri)
        api_response = JSON.parse(json)

        stock_data = api_response['data'][0]

        "Ticker #{stock_data['symbol']} had a day close of #{stock_data['close'].to_s} on #{stock_data['date'].to_s}, with a high of #{stock_data['high'].to_s} and a low of #{stock_data['low'].to_s}"
      rescue
        "ERROR: Had trouble retrieving information from Market Stack for stock market information!"
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class WebCrawlerFunction < Function

    def name
      'web_crawler'
    end

    def description
      I18n.t("chatbot.prompt.function.web_crawler.description")
    end

    def parameters
      [
        { name: 'url', type: String, description: I18n.t("chatbot.prompt.function.web_crawler.parameters.url") },
      ]
    end

    def required
      ['url']
    end

    def process(args)
      begin
        ::DiscourseChatbot.progress_debug_message <<~EOS
        -------------------------------------
        arguments for web crawler: #{args[parameters[0][:name]]}
        --------------------------------------
        EOS
        super(args)
        token_usage = 0
        if SiteSetting.chatbot_firecrawl_api_token.blank?
          conn = Faraday.new(
            url: "https://r.jina.ai/#{args[parameters[0][:name]]}",
            headers: {
              "Authorization" => "Bearer #{SiteSetting.chatbot_jina_api_token}"
            }
          )
          response = conn.get
          result = response.body
          token_usage =  result.length * SiteSetting.chatbot_jina_api_token_cost_multiplier
        else
          conn = Faraday.new(
            url: 'https://api.firecrawl.dev',
            headers: {
              "Content-Type" => "application/json",
              "Authorization" => "Bearer #{SiteSetting.chatbot_firecrawl_api_token}"
            }
          )

          response = conn.post('v0/crawl') do |req|
            req.body = { url: "#{args[parameters[0][:name]]}" }.to_json
          end

          response_body = JSON.parse(response.body)

          job_id = response_body["jobId"]

          iterations = 0
          while true
            iterations += 1
            sleep 5
            break if iterations > 20

            response = conn.get("/v0/crawl/status/#{job_id}")

            response_body = JSON.parse(response.body)

            break if response_body["status"] == "completed"
          end

          result = response_body["data"][0]["markdown"]
          token_usage = SiteSetting.chatbot_firecrawl_api_token_cost
        end
        {
          answer: result[0..SiteSetting.chatbot_function_response_char_limit],
          token_usage: token_usage
        }
      rescue=> e
        Rails.logger.error("Chatbot: Error in web crawler function: #{e}")
        {
          answer: I18n.t("chatbot.prompt.function.web_crawler.error"),
          token_usage: token_usage
        }
      end
    end
  end
end

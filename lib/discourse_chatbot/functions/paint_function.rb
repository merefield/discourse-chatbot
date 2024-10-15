# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class PaintFunction < Function
    TOKEN_COST = 1000000 # 1M tokens per request based on cost of dall-e-3 model vs gpt-4o-mini

    def name
      'paint_picture'
    end

    def description
      I18n.t("chatbot.prompt.function.paint.description")
    end

    def parameters
      [
        { name: "description", type: String, description: I18n.t("chatbot.prompt.function.paint.parameters.description") } ,
      ]
    end

    def required
      ['description']
    end

    def process(args)
      begin
        super(args)
        token_usage = 0

        description = args[parameters[0][:name]]

        client = OpenAI::Client.new do |f|
          f.response :logger, Logger.new($stdout), bodies: true if SiteSetting.chatbot_enable_verbose_console_logging
          if SiteSetting.chatbot_enable_verbose_rails_logging != "off"
            case SiteSetting.chatbot_verbose_rails_logging_destination_level
              when "warn"
                f.response :logger, Rails.logger, bodies: true, log_level: :warn
              else
                f.response :logger, Rails.logger, bodies: true, log_level: :info
            end
          end
        end

        response = client.images.generate(parameters: { prompt: description, model: "dall-e-3", size: "1792x1024", quality: "standard" })

        if response.dig("error")
          error_text = "ERROR when trying to call paint API: #{response.dig("error", "message")}"
          raise StandardError, error_text
        end

        {
          answer: response.dig("data", 0, "url"),
          token_usage: TOKEN_COST
        }
      rescue => e
        Rails.logger.error("Chatbot: Error in paint function: #{e}")
        {
          answer: I18n.t("chatbot.prompt.function.paint.error"),
          token_usage: TOKEN_COST
        }
      end
    end
  end
end

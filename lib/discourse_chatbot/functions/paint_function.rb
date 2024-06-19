# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class PaintFunction < Function

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

        response.dig("data", 0, "url")
      rescue
        I18n.t("chatbot.prompt.function.paint.error")
      end
    end
  end
end

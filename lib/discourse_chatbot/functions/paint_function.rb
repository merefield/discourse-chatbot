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

        size = SiteSetting.chatbot_support_picture_creation_model == "dall-e-3" ? "1792x1024" : "1536x1024"
        quality = SiteSetting.chatbot_support_picture_creation_model == "dall-e-3" ? "standard" : "auto"

        options = {
          model: SiteSetting.chatbot_support_picture_creation_model,
          prompt: description,
          size: size,
          quality: quality,
       }

        options.merge!(response_format: "b64_json") if SiteSetting.chatbot_support_picture_creation_model == "dall-e-3"
        options.merge!(style: "natural") if SiteSetting.chatbot_support_picture_creation_model == "dall-e-3"
        options.merge!(moderation: "low") if SiteSetting.chatbot_support_picture_creation_model == "gpt-image-1"

        response = client.images.generate(parameters: options)

        if response.dig("error")
          error_text = "ERROR when trying to call paint API: #{response.dig("error", "message")}"
          raise StandardError, error_text
        end

        tokens_used = SiteSetting.chatbot_support_picture_creation_model == "gpt-image-1" ? response.dig("usage", "total_tokens") : TOKEN_COST

        artifacts = response.dig("data")
          .to_a
          .map { |art| art["b64_json"] }

        bot_username = SiteSetting.chatbot_bot_user
        bot_user = ::User.find_by(username: bot_username)

        thumbnails = base64_to_image(artifacts, description, bot_user.id)
        short_url = thumbnails.first.short_url
        markdown = "![#{description}|690x460](#{short_url})"

        {
          answer: markdown,
          token_usage: tokens_used
        }
      rescue => e
        Rails.logger.error("Chatbot: Error in paint function: #{e}")
        {
          answer: I18n.t("chatbot.prompt.function.paint.error"),
          token_usage: TOKEN_COST
        }
      end
    end

    private

    def base64_to_image(artifacts, description, user_id)
      attribution = description

      artifacts.each_with_index.map do |art, i|
        f = Tempfile.new("v1_txt2img_#{i}.png")
        f.binmode
        f.write(Base64.decode64(art))
        f.rewind
        upload = UploadCreator.new(f, attribution).create_for(user_id)
        f.unlink

        UploadSerializer.new(upload, root: false)
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../function"

module DiscourseChatbot
  class PaintFunction < Function
    TOKEN_COST = 1_000_000 # 1M tokens per request based on cost of dall-e-3 model vs gpt-4o-mini
    ASPECT_RATIO_OPTIONS = %w[square landscape portrait].freeze
    DEFAULT_ASPECT_RATIO = "landscape"
    SIZE_BY_MODEL_AND_ASPECT_RATIO = {
      "dall-e-2" => {
        "square" => "1024x1024",
        "landscape" => "1024x1024",
        "portrait" => "1024x1024",
      }.freeze,
      "dall-e-3" => {
        "square" => "1024x1024",
        "landscape" => "1792x1024",
        "portrait" => "1024x1792",
      }.freeze,
      "gpt-image" => {
        "square" => "1024x1024",
        "landscape" => "1536x1024",
        "portrait" => "1024x1536",
      }.freeze,
    }.freeze

    def name
      "paint_picture"
    end

    def description
      I18n.t("chatbot.prompt.function.paint.description")
    end

    def parameters
      [
        {
          name: "description",
          type: String,
          description: I18n.t("chatbot.prompt.function.paint.parameters.description"),
        },
        {
          name: "aspect_ratio",
          type: String,
          enum: ASPECT_RATIO_OPTIONS,
          description: I18n.t("chatbot.prompt.function.paint.parameters.aspect_ratio"),
        },
      ]
    end

    def required
      ["description"]
    end

    def process(args)
      begin
        super(args)
        token_usage = 0

        description = args[parameters[0][:name]]
        aspect_ratio = self.class.normalized_aspect_ratio(args[parameters[1][:name]])

        client =
          OpenAI::Client.new do |f|
            if SiteSetting.chatbot_enable_verbose_console_logging
              f.response :logger, Logger.new($stdout), bodies: true
            end
            if SiteSetting.chatbot_enable_verbose_rails_logging != "off"
              case SiteSetting.chatbot_verbose_rails_logging_destination_level
              when "warn"
                f.response :logger, Rails.logger, bodies: true, log_level: :warn
              else
                f.response :logger, Rails.logger, bodies: true, log_level: :info
              end
            end
          end

        size = self.class.size_for(SiteSetting.chatbot_support_picture_creation_model, aspect_ratio)
        quality =
          SiteSetting.chatbot_support_picture_creation_model == "dall-e-3" ? "standard" : "auto"

        options = {
          model: SiteSetting.chatbot_support_picture_creation_model,
          prompt: description,
          size: size,
          quality: quality,
        }

        if SiteSetting.chatbot_support_picture_creation_model == "dall-e-3"
          options.merge!(response_format: "b64_json")
        end
        if SiteSetting.chatbot_support_picture_creation_model == "dall-e-3"
          options.merge!(style: "natural")
        end
        options.merge!(moderation: "low") if gpt_image_model?

        response = client.images.generate(parameters: options)

        if response.dig("error")
          error_text = "ERROR when trying to call paint API: #{response.dig("error", "message")}"
          raise StandardError, error_text
        end

        tokens_used = gpt_image_model? ? response.dig("usage", "total_tokens") : TOKEN_COST

        artifacts = response.dig("data").to_a.map { |art| art["b64_json"] }

        bot_username = SiteSetting.chatbot_bot_user
        bot_user = ::User.find_by(username: bot_username)

        thumbnails = base64_to_image(artifacts, description, bot_user.id)
        markdown =
          self.class.markdown_for(
            upload: thumbnails.first,
            description: description,
            fallback_size: size,
          )

        { answer: markdown, token_usage: tokens_used }
      rescue => e
        Rails.logger.error("Chatbot: Error in paint function: #{e}")
        if e.respond_to?(:response)
          status = e.response[:status]
          message = e.response[:body]["error"]["message"]
          Rails.logger.error(
            "Chatbot: There was a problem with Image call: status: #{status}, message: #{message}",
          )
        end
        { answer: I18n.t("chatbot.prompt.function.paint.error"), token_usage: TOKEN_COST }
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

        upload
      end
    end

    def gpt_image_model?
      SiteSetting.chatbot_support_picture_creation_model.start_with?("gpt-image-")
    end

    class << self
      def normalized_aspect_ratio(aspect_ratio)
        aspect_ratio.presence || DEFAULT_ASPECT_RATIO
      end

      def size_for(model_name, aspect_ratio)
        model_family = image_model_family(model_name)
        SIZE_BY_MODEL_AND_ASPECT_RATIO[model_family][aspect_ratio]
      end

      def aspect_ratio_for_upload(upload)
        return DEFAULT_ASPECT_RATIO if upload.blank? || upload.width.blank? || upload.height.blank?
        return "square" if upload.width == upload.height

        upload.width > upload.height ? "landscape" : "portrait"
      end

      def markdown_for(upload:, description:, fallback_size:)
        width, height = size_dimensions(fallback_size)
        width = upload.width.presence || width
        height = upload.height.presence || height

        "![#{description}|#{width}x#{height}](#{upload.short_url})"
      end

      private

      def image_model_family(model_name)
        return "gpt-image" if model_name.start_with?("gpt-image-")

        model_name
      end

      def size_dimensions(size)
        size.split("x").map(&:to_i)
      end
    end
  end
end

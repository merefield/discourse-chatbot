# frozen_string_literal: true

module DiscourseChatbot
  module Tools
    class Paint < ::DiscourseChatbot::Tool
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
        "gemini-image" => {
          "square" => "1024x1024",
          "landscape" => "1536x1024",
          "portrait" => "1024x1536",
        }.freeze,
        "grok-imagine" => {
          "square" => "1024x1024",
          "landscape" => "1792x1024",
          "portrait" => "1024x1792",
        }.freeze,
      }.freeze
      X_AI_ASPECT_RATIOS = { "square" => "1:1", "landscape" => "16:9", "portrait" => "9:16" }.freeze

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

          provider = SiteSetting.chatbot_image_provider
          model_name = ::DiscourseChatbot.image_model_name
          client =
            ::DiscourseChatbot::LlmClient.build_client(
              provider: provider,
              custom_uri_base: SiteSetting.chatbot_image_model_custom_url,
              azure:
                provider == "open_ai" &&
                  SiteSetting.chatbot_open_ai_model_custom_api_type == "azure",
            )

          size = self.class.size_for(model_name, aspect_ratio)

          options = generation_options(provider, model_name, description, aspect_ratio, size)

          response = client.images.generate(parameters: options)

          if response.dig("error")
            error_text = "ERROR when trying to call paint API: #{response.dig("error", "message")}"
            raise StandardError, error_text
          end

          tokens_used =
            (
              if gpt_image_model?(provider, model_name)
                response.dig("usage", "total_tokens")
              else
                TOKEN_COST
              end
            )

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
          Rails.logger.error("Chatbot: Error in paint tool: #{e}")
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
          begin
            upload = UploadCreator.new(f, attribution).create_for(user_id)
          ensure
            f.close
            f.unlink
          end

          upload
        end
      end

      def generation_options(provider, model_name, description, aspect_ratio, size)
        options = { model: model_name, prompt: description, response_format: "b64_json", n: 1 }

        case provider
        when "open_ai"
          options.merge!(size: size, quality: model_name == "dall-e-3" ? "standard" : "auto")
          options[:style] = "natural" if model_name == "dall-e-3"
          options[:moderation] = "low" if gpt_image_model?(provider, model_name)
        when "google_gemini"
          options[:size] = size
        when "x_ai"
          options[:aspect_ratio] = X_AI_ASPECT_RATIOS.fetch(aspect_ratio)
        end

        options
      end

      def gpt_image_model?(provider, model_name)
        provider == "open_ai" && model_name.start_with?("gpt-image-")
      end

      class << self
        def normalized_aspect_ratio(aspect_ratio)
          aspect_ratio.presence || DEFAULT_ASPECT_RATIO
        end

        def size_for(model_name, aspect_ratio)
          model_family = image_model_family(model_name)
          sizes =
            SIZE_BY_MODEL_AND_ASPECT_RATIO.fetch(
              model_family,
              SIZE_BY_MODEL_AND_ASPECT_RATIO["gpt-image"],
            )
          sizes.fetch(aspect_ratio)
        end

        def aspect_ratio_for_upload(upload)
          if upload.blank? || upload.width.blank? || upload.height.blank?
            return DEFAULT_ASPECT_RATIO
          end
          return "square" if upload.width == upload.height

          upload.width > upload.height ? "landscape" : "portrait"
        end

        def markdown_for(upload:, description:, fallback_size:)
          width, height = size_dimensions(fallback_size)
          width = upload.width.presence || width
          height = upload.height.presence || height

          "![#{description}|#{width}x#{height}](#{upload.short_url})"
        end

        def image_edit_supported?
          provider = SiteSetting.chatbot_image_provider
          return true if provider == "x_ai"

          provider == "open_ai" && ::DiscourseChatbot.image_model_name.start_with?("gpt-image-")
        end

        private

        def image_model_family(model_name)
          return "gpt-image" if model_name.start_with?("gpt-image-")
          return "gemini-image" if model_name.start_with?("gemini-")
          return "grok-imagine" if model_name.start_with?("grok-imagine-")

          model_name
        end

        def size_dimensions(size)
          size.split("x").map(&:to_i)
        end
      end
    end
  end
end

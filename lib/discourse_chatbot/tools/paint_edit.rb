# frozen_string_literal: true

module DiscourseChatbot
  module Tools
    class PaintEdit < ::DiscourseChatbot::Tool
      TOKEN_COST = 1_000_000 # 1M tokens per request based on cost of dall-e-3 model vs gpt-4o-mini

      def name
        "paint_edit_picture"
      end

      def description
        I18n.t("chatbot.prompt.function.paint_edit.description")
      end

      def parameters
        [
          {
            name: "description",
            type: String,
            description: I18n.t("chatbot.prompt.function.paint_edit.parameters.description"),
          },
          {
            name: "aspect_ratio",
            type: String,
            enum: Paint::ASPECT_RATIO_OPTIONS,
            description: I18n.t("chatbot.prompt.function.paint_edit.parameters.aspect_ratio"),
          },
        ]
      end

      def required
        ["description"]
      end

      def process(args, opts)
        begin
          super(args)
          token_usage = 0

          description = args[parameters[0][:name]]

          provider = SiteSetting.chatbot_image_provider
          model_name = ::DiscourseChatbot.image_model_name

          type = opts[:type]

          last_image_upload =
            (
              if type == ::DiscourseChatbot::POST
                last_post_image_upload(opts[:reply_to_message_or_post_id])
              else
                last_message_image_upload(opts[:reply_to_message_or_post_id])
              end
            )

          if last_image_upload.nil?
            return(
              {
                answer: I18n.t("chatbot.prompt.function.paint_edit.no_image_error"),
                token_usage: 0,
              }
            )
          end

          aspect_ratio = resolved_aspect_ratio(args[parameters[1][:name]], last_image_upload)
          size = Paint.size_for(model_name, aspect_ratio)

          options = {
            model: model_name,
            prompt: description,
            size: size,
            quality: "auto",
            response_format: "b64_json",
          }

          file_path = Discourse.store.path_for(last_image_upload)
          extension = last_image_upload.extension
          mime_type = MiniMime.lookup_by_extension(extension).content_type

          response =
            if provider == "x_ai"
              x_ai_edit_response(options.except(:size, :quality), file_path, mime_type)
            else
              open_ai_edit_response(options, file_path, extension, mime_type)
            end

          if response.dig("error")
            error_text = "ERROR when trying to call paint API: #{response.dig("error", "message")}"
            raise StandardError, error_text
          end

          tokens_used = response.dig("usage", "total_tokens") || TOKEN_COST

          artifacts = response.dig("data").to_a.map { |art| art["b64_json"] }

          bot_username = SiteSetting.chatbot_bot_user
          bot_user = ::User.find_by(username: bot_username)

          thumbnails = base64_to_image(artifacts, description, bot_user.id)
          markdown =
            Paint.markdown_for(
              upload: thumbnails.first,
              description: description,
              fallback_size: size,
            )

          { answer: markdown, token_usage: tokens_used }
        rescue => e
          Rails.logger.error("Chatbot: Error in paint edit tool: #{e}")
          if e.respond_to?(:response)
            status = e.response[:status]
            message = e.response[:body]["error"]["message"]
            Rails.logger.error(
              "Chatbot: There was a problem with Image call: status: #{status}, message: #{message}",
            )
          end
          { answer: I18n.t("chatbot.prompt.function.paint_edit.error"), token_usage: TOKEN_COST }
        end
      end

      private

      def open_ai_edit_response(options, file_path, extension, mime_type)
        client =
          ::DiscourseChatbot::LlmClient.build_client(
            provider: "open_ai",
            custom_uri_base: SiteSetting.chatbot_image_model_custom_url,
            azure: SiteSetting.chatbot_open_ai_model_custom_api_type == "azure",
          )
        file = Tempfile.new(["e1_image", ".#{extension}"])
        file.binmode
        file.write(File.binread(file_path))
        file.rewind
        options[:image] = Faraday::Multipart::FilePart.new(file, mime_type)
        client.images.edit(parameters: options)
      ensure
        file&.close
        file&.unlink
      end

      def x_ai_edit_response(options, file_path, mime_type)
        config =
          ::DiscourseChatbot::LlmClient.client_config(
            provider: "x_ai",
            custom_uri_base: SiteSetting.chatbot_image_model_custom_url,
          )
        endpoint = "#{config[:uri_base].delete_suffix("/")}/images/edits"
        image_data = Base64.strict_encode64(File.binread(file_path))
        parameters =
          options.merge(image: { type: "image_url", url: "data:#{mime_type};base64,#{image_data}" })
        response =
          Faraday.post(endpoint) do |request|
            request.headers["Authorization"] = "Bearer #{config[:access_token]}"
            request.headers["Content-Type"] = "application/json"
            request.body = JSON.generate(parameters)
          end

        JSON.parse(response.body)
      end

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

      def resolved_aspect_ratio(aspect_ratio, upload)
        return Paint.normalized_aspect_ratio(aspect_ratio) if aspect_ratio.present?

        Paint.aspect_ratio_for_upload(upload)
      end

      def last_post_image_upload(post_id)
        post_collection =
          ::DiscourseChatbot::Post::PostPromptUtils.collect_past_interactions(post_id)

        return nil if post_collection.empty?

        upload_id = post_collection.map(&:image_upload_id).compact.max
        Upload.find_by(id: upload_id)
      end

      def last_message_image_upload(message_id)
        message_collection =
          ::DiscourseChatbot::Message::MessagePromptUtils.collect_past_interactions(message_id)
        uploads = []

        message_collection.each do |cm|
          cm.uploads.each { |ul| uploads << ul if %w[png webp jpg jpeg].include?(ul.extension) }
        end

        return nil if uploads.empty?

        uploads.max_by(&:created_at)
      end
    end
  end
end

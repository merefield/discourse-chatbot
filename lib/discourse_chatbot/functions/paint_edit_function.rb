# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class PaintEditFunction < Function
    TOKEN_COST = 1000000 # 1M tokens per request based on cost of dall-e-3 model vs gpt-4o-mini

    def name
      'paint_edit_picture'
    end

    def description
      I18n.t("chatbot.prompt.function.paint_edit.description")
    end

    def parameters
      [
        { name: "description", type: String, description: I18n.t("chatbot.prompt.function.paint_edit.parameters.description") } ,
      ]
    end

    def required
      ['description']
    end

    def process(args, opts)
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

        size = "1536x1024"
        quality = "auto"

        options = {
          model: SiteSetting.chatbot_support_picture_creation_model,
          prompt: description,
          size: size,
          quality: quality,
       }

        type = opts[:type]

        last_image_upload = type == ::DiscourseChatbot::POST ? last_post_image_upload(opts[:reply_to_message_or_post_id]) : last_message_image_upload(opts[:reply_to_message_or_post_id])

        return {
          answer: I18n.t("chatbot.prompt.function.paint_edit.no_image_error"),
          token_usage: 0
        } if last_image_upload.nil?

        file_path = path = Discourse.store.path_for(last_image_upload)
        base64_encoded_data = Base64.strict_encode64(File.read(file_path))

        file_path = Discourse.store.path_for(last_image_upload)
        extension = last_image_upload.extension
        mime_type = MiniMime.lookup_by_extension(extension).content_type

        f = Tempfile.new(["e1_image", ".#{extension}"])
        f.binmode
        f.write(File.binread(file_path))
        f.rewind
        
        # Specify the file with MIME type
        upload_io = Faraday::Multipart::FilePart.new(f, mime_type)
        
        options[:image] = upload_io
        
        response = client.images.edit(parameters: options)
        
        f.close
        f.unlink

        if response.dig("error")
          error_text = "ERROR when trying to call paint API: #{response.dig("error", "message")}"
          raise StandardError, error_text
        end

        tokens_used = response.dig("usage", "total_tokens")

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
        Rails.logger.error("Chatbot: Error in paint edit function: #{e}")
        if e.respond_to?(:response)
          status = e.response[:status]
          message = e.response[:body]["error"]["message"]
          Rails.logger.error("Chatbot: There was a problem with Image call: status: #{status}, message: #{message}")
        end
        {
          answer: I18n.t("chatbot.prompt.function.paint_edit.error"),
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

    def last_post_image_upload(post_id)
      post_collection = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_id)

      return nil if post_collection.empty?
    
      upload_id = post_collection.map(&:image_upload_id).compact.max
      return Upload.find_by(id: upload_id)
    
      nil
    end

    def last_message_image_upload(message_id)
      message_collection = ::DiscourseChatbot::MessagePromptUtils.collect_past_interactions(message_id)
      uploads = []

      message_collection.each do |cm|
        cm.uploads.each do |ul|
          if %w[png webp jpg jpeg].include?(ul.extension)
            uploads << ul
          end
        end
      end

      return nil if uploads.empty?

      uploads.max_by(&:created_at)
    end
  end
end

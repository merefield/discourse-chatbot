# frozen_string_literal: true

module DiscourseChatbot
  module Tools
    class Vision < ::DiscourseChatbot::Tool
      def name
        "vision"
      end

      def description
        I18n.t("chatbot.prompt.function.vision.description")
      end

      def parameters
        [
          {
            name: "query",
            type: String,
            description: I18n.t("chatbot.prompt.function.vision.parameters.query"),
          },
        ]
      end

      def required
        []
      end

      def process(args, opts, _chat_client)
        begin
          token_usage = 0
          super(args)

          if args[parameters[0][:name]].blank?
            query = I18n.t("chatbot.prompt.function.vision.default_query")
          else
            query = args[parameters[0][:name]]
          end

          url = ""

          if opts[:type] == ::DiscourseChatbot::MESSAGE
            collection =
              ::DiscourseChatbot::Message::MessagePromptUtils.collect_past_interactions(
                opts[:reply_to_message_or_post_id],
              )
            collection.each do |m|
              m.uploads.each do |ul|
                if %w[png webp jpg jpeg gif ico avif].include?(ul.extension)
                  url = ::DiscourseChatbot::PromptUtils.resolve_full_url(ul.url)
                  break
                end
              end
              break if url.present?
            end
          else
            collection =
              ::DiscourseChatbot::Post::PostPromptUtils.collect_past_interactions(
                opts[:reply_to_message_or_post_id],
              )
            collection.each do |p|
              if p.image_upload_id
                url =
                  ::DiscourseChatbot::PromptUtils.resolve_full_url(
                    ::Upload.find(p.image_upload_id).url,
                  )
                break
              end
            end
          end

          if url.present?
            provider = SiteSetting.chatbot_vision_provider
            client =
              ::DiscourseChatbot::LlmClient.build_client(
                provider: provider,
                custom_uri_base: SiteSetting.chatbot_vision_model_custom_url,
                azure:
                  provider == "open_ai" &&
                    SiteSetting.chatbot_open_ai_model_custom_api_type == "azure",
              )
            res, description = vision_response(client, provider, query, url)
            token_usage = res.dig("usage", "total_tokens") || 0

            if res.dig("error")
              error_text =
                "ERROR when trying to perform chat completion for vision: #{res.dig("error", "message")}"

              Rails.logger.error("Chatbot: #{error_text}")

              raise error_text
            end
          else
            error_text = "ERROR when trying to find image for examination: no image found"

            Rails.logger.error("Chatbot: #{error_text}")

            raise error_text
          end

          {
            answer: I18n.t("chatbot.prompt.function.vision.answer", description: description),
            token_usage: token_usage,
          }
        rescue => e
          {
            answer: I18n.t("chatbot.prompt.function.vision.error", error: e.message),
            token_usage: token_usage,
          }
        end
      end

      private

      def vision_response(client, provider, query, url)
        if provider == "x_ai"
          response =
            client.responses.create(
              parameters: {
                model: ::DiscourseChatbot.vision_model_name,
                input: [
                  {
                    role: "user",
                    content: [
                      { type: "input_image", image_url: url },
                      { type: "input_text", text: query },
                    ],
                  },
                ],
                max_output_tokens: 300,
              },
            )
          text =
            Array(response["output"])
              .flat_map { |output| Array(output["content"]) }
              .filter_map { |content| content["text"] if content["type"] == "output_text" }
              .join
          return response, text
        end

        response =
          client.chat(
            parameters: {
              model: ::DiscourseChatbot.vision_model_name,
              messages: [
                {
                  role: "user",
                  content: [
                    { type: "text", text: query },
                    { type: "image_url", image_url: { url: url } },
                  ],
                },
              ],
              max_tokens: 300,
            },
          )
        [response, response.dig("choices", 0, "message", "content")]
      end
    end
  end
end

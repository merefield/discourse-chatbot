# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot

  class VisionFunction < Function

    def name
      'vision'
    end

    def description
      I18n.t("chatbot.prompt.function.vision.description")
    end

    def parameters
      [
       { name: 'query', type: String, description: I18n.t("chatbot.prompt.function.vision.parameters.query") }
      ]
    end

    def required
      []
    end

    def process(args, opts, client)
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
          collection = ::DiscourseChatbot::MessagePromptUtils.collect_past_interactions(opts[:reply_to_message_or_post_id])
          collection.each do |m|
            m.uploads.each do |ul|
              if ["png", "webp", "jpg", "jpeg", "gif", "ico", "avif"].include?(ul.extension)
                url = ::DiscourseChatbot::PromptUtils.resolve_full_url(ul.url)
                break
              end
            end
            break if !url.blank?
          end
        else
          collection = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(opts[:reply_to_message_or_post_id])
          collection.each do |p|
            if p.image_upload_id
              url = ::DiscourseChatbot::PromptUtils.resolve_full_url(::Upload.find(p.image_upload_id).url)
              break
            end
          end
        end

        if !url.blank?
          res = client.chat(
            parameters: {
              model: SiteSetting.chatbot_open_ai_vision_model,
              messages: [
                {
                  "role": "user",
                  "content": [
                    {"type": "text", "text": query},
                    {
                      "type": "image_url",
                      "image_url": {
                        "url": url,
                      },
                    },
                  ],
                }
              ],
              max_tokens: 300
            }
          )

          token_usage = res.dig("usage", "total_tokens")

          if res.dig("error")
            error_text = "ERROR when trying to perform chat completion for vision: #{res.dig("error", "message")}"

            Rails.logger.error("Chatbot: #{error_text}")

            raise error_text
          end
        else
          error_text = "ERROR when trying to find image for examination: no image found"

          Rails.logger.error("Chatbot: #{error_text}")

          raise error_text
        end

        {
          answer: I18n.t("chatbot.prompt.function.vision.answer", description: res["choices"][0]["message"]["content"]),
          token_usage: token_usage
        }
      rescue => e
        {
          answer: I18n.t("chatbot.prompt.function.vision.error", error: e.message),
          token_usage: token_usage
        }
      end
    end
  end
end

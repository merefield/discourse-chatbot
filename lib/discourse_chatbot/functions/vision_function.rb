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
       { name: 'url', type: String, description: I18n.t("chatbot.prompt.function.vision.parameters.url") }
      ]
    end

    def required
      ['url']
    end

    def process(args, client)
      begin
        super(args)

        res = client.chat(
          parameters: {
            model: SiteSetting.chatbot_open_ai_vision_model,
            messages: [
              {
                "role": "user",
                "content": [
                  {"type": "text", "text": "What’s in this image?"},
                  {
                    "type": "image_url",
                    "image_url": {
                      "url": args[parameters[0][:name]],
                    },
                  },
                ],
              }
            ],
            max_tokens: 300
          }
        )

        if res.dig("error")
          error_text = "ERROR when trying to perform chat completion for vision: #{res.dig("error", "message")}"

          Rails.logger.error("Chatbot: #{error_text}")

          raise error_text
        end

        I18n.t("chatbot.prompt.function.vision.answer", description: res["choices"][0]["message"]["content"])
      rescue => e
        I18n.t("chatbot.prompt.function.vision.error", error: e.message)
      end
    end
  end
end

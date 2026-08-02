# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class CalculatorFunction < ::DiscourseChatbot::Function
      def name
        "calculate"
      end

      def description
        I18n.t("chatbot.prompt.function.calculator.description")
      end

      def parameters
        [
          {
            name: "input",
            type: String,
            description: I18n.t("chatbot.prompt.function.calculator.parameters.input"),
          },
        ]
      end

      def required
        ["input"]
      end

      def process(args)
        super(args)

        {
          answer: ::DiscourseChatbot::Calculator.evaluate(args[parameters[0][:name]]),
          token_usage: 0,
        }
      rescue StandardError
        {
          answer:
            I18n.t(
              "chatbot.prompt.function.calculator.error",
              parameter: args[parameters[0][:name]],
            ),
          token_usage: 0,
        }
      end
    end
  end
end

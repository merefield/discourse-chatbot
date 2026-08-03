# frozen_string_literal: true

module DiscourseChatbot
  module Tools
    class Calculator < ::DiscourseChatbot::Tool
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
        input = args[parameters[0][:name]]
        if failed_inputs.include?(input)
          return(
            {
              answer: I18n.t("chatbot.prompt.function.calculator.repeated_error", parameter: input),
              token_usage: 0,
            }
          )
        end

        super(args)

        { answer: ::DiscourseChatbot::Calculator.evaluate(input), token_usage: 0 }
      rescue ::DiscourseChatbot::Calculator::InvalidExpression
        failed_inputs << input
        {
          answer: I18n.t("chatbot.prompt.function.calculator.error", parameter: input),
          token_usage: 0,
        }
      rescue StandardError
        {
          answer: I18n.t("chatbot.prompt.function.calculator.error", parameter: input),
          token_usage: 0,
        }
      end

      private

      def failed_inputs
        @failed_inputs ||= []
      end
    end
  end
end

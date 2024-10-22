# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class CalculatorFunction < Function

    def name
      'calculate'
    end

    def description
      I18n.t("chatbot.prompt.function.calculator.description")
    end

    def parameters
      [
        { name: "input", type: String, description: I18n.t("chatbot.prompt.function.calculator.parameters.input") } ,
      ]
    end

    def required
      ['input']
    end

    def process(args)
      begin
        super(args)

        {
          answer: ::SafeRuby.eval(args[parameters[0][:name]], timeout: 5),
          token_usage: 0
        }
      rescue
        {
          answer: I18n.t("chatbot.prompt.function.calculator.error", parameter: args[parameters[0][:name]]),
          token_usage: 0
        }
      end
    end
  end
end

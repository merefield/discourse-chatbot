# frozen_string_literal: true

module DiscourseChatbot
  module Tools
    class FunctionPlot < ::DiscourseChatbot::Tool
      def name
        "plot_function"
      end

      def description
        I18n.t("chatbot.prompt.function.function_plot.description")
      end

      def parameters
        [
          {
            name: "expressions",
            type: String,
            description: I18n.t("chatbot.prompt.function.function_plot.expressions"),
          },
          {
            name: "title",
            type: String,
            description: I18n.t("chatbot.prompt.function.function_plot.title"),
          },
          *%w[x_min x_max y_min y_max].map do |name|
            {
              name: name,
              type: Numeric,
              description: I18n.t("chatbot.prompt.function.function_plot.#{name}"),
            }
          end,
        ]
      end

      def required
        ["expressions"]
      end

      def process(args)
        super(args)
        { answer: ::DiscourseChatbot::FunctionPlot.markdown(args), token_usage: 0 }
      rescue ArgumentError
        { answer: I18n.t("chatbot.prompt.function.function_plot.error"), token_usage: 0 }
      end
    end
  end
end

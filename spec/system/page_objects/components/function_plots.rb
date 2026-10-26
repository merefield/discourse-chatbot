# frozen_string_literal: true

module PageObjects
  module Components
    class FunctionPlots < PageObjects::Components::Base
      def has_rendered_graphs?(count:)
        page.has_css?(".chatbot-function-plot__canvas svg.function-plot", count: count) &&
          page.has_css?(".chatbot-function-plot__canvas path.line", minimum: count)
      end

      def has_error?
        page.has_css?(
          ".chatbot-function-plot__error",
          text: I18n.t("js.chatbot.function_plot.error"),
        )
      end

      def has_no_error?
        page.has_no_css?(".chatbot-function-plot__error")
      end

      def has_separate_domain_segments?
        page.has_css?(".chatbot-function-plot__canvas path.line-0", count: 2) &&
          page.has_no_css?(".chatbot-function-plot__canvas path.line-1")
      end
    end
  end
end

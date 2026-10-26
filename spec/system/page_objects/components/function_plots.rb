# frozen_string_literal: true

module PageObjects
  module Components
    class FunctionPlots < PageObjects::Components::Base
      def has_rendered_graphs?(count:)
        page.has_css?(".chatbot-function-plot__canvas svg", count: count) &&
          page.has_css?(".chatbot-function-plot__canvas .graph", minimum: count)
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
        page.has_css?(".chatbot-function-plot__canvas .graph path.line-0", count: 2)
      end

      def move_over_2d_plot(relative_x:)
        page.driver.with_playwright_page do |browser_page|
          canvas = browser_page.locator(".chatbot-function-plot__canvas .zoom-and-drag").first
          canvas.scroll_into_view_if_needed
          box = canvas.bounding_box
          browser_page.mouse.move(
            box["x"] + box["width"] * relative_x,
            box["y"] + box["height"] / 2,
          )
        end
      end

      def leave_plot
        page.driver.with_playwright_page do |browser_page|
          browser_page.mouse.move(browser_page.evaluate("window.innerWidth") - 40, 500)
        end
      end

      def has_trace_points?(count:)
        page.has_css?(".chatbot-function-plot__trace-point", count: count)
      end

      def has_trace_values?(count:)
        page.has_css?(".chatbot-function-plot__coordinates:not(:empty)", count: count)
      end

      def trace_coordinates
        all(".chatbot-function-plot__coordinates", visible: :all).map do |readout|
          readout
            .text
            .match(/x = ([+-]?\d+(?:\.\d+)?), y = ([+-]?\d+(?:\.\d+)?)/)
            &.captures
            &.map(&:to_f)
        end
      end

      def trace_point_positions
        all(".chatbot-function-plot__trace-point").map { |point| [point[:cx], point[:cy]] }
      end

      def has_implicit_curve?
        page.has_css?("[data-plot-type='implicit'] .graph path", minimum: 1)
      end

      def has_scatter_points?(count:)
        page.has_css?("[data-plot-type='points'] .graph circle", count: count)
      end

      def has_vector_arrows?(count:)
        page.has_css?("[data-plot-type='vector'] .graph path[marker-end^='url']", count: count)
      end

      def has_finite_paths?
        all(".chatbot-function-plot__canvas .graph path").all? do |path|
          path[:d].present? && !path[:d].match?(/NaN|Infinity/)
        end
      end

      def has_no_visible_canvas?
        page.has_no_css?(".chatbot-function-plot__canvas")
      end

      def pan_plot
        page.driver.with_playwright_page do |browser_page|
          canvas = browser_page.locator(".chatbot-function-plot__canvas .zoom-and-drag").first
          canvas.scroll_into_view_if_needed
          box = canvas.bounding_box
          browser_page.mouse.move(box["x"] + 200, box["y"] + 150)
          browser_page.mouse.down
          browser_page.mouse.move(box["x"] + 280, box["y"] + 190, steps: 10)
          browser_page.mouse.up
        end
      end

      def curve_path
        find(".chatbot-function-plot__canvas .graph path.line", match: :first)[:d]
      end

      def zoom_plot(delta_y: -300)
        page.driver.with_playwright_page do |browser_page|
          canvas = browser_page.locator(".chatbot-function-plot__canvas .zoom-and-drag").first
          box = canvas.bounding_box
          browser_page.mouse.move(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
          browser_page.mouse.wheel(0, delta_y)
        end
      end

      def page_scroll_position
        page.evaluate_async_script(<<~JS)
          const done = arguments[0];
          requestAnimationFrame(() => requestAnimationFrame(() => done(window.scrollY)));
        JS
      end

      def scroll_outside_plot
        page.driver.with_playwright_page do |browser_page|
          viewport_width = browser_page.evaluate("window.innerWidth")
          browser_page.mouse.move(viewport_width - 40, 500)
          browser_page.mouse.wheel(0, 300)
        end
      end
    end
  end
end

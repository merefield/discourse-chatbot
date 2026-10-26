# frozen_string_literal: true

module PageObjects
  module Components
    class FunctionPlots < PageObjects::Components::Base
      def has_rendered_graphs?(count:)
        page.has_css?(".chatbot-function-plot__canvas svg", count: count) &&
          page.has_css?(".chatbot-function-plot__curve", minimum: count)
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
        path = find(".chatbot-function-plot__curve[data-curve='0']")
        path["d"].scan(/M/i).length >= 2
      end

      def move_over_2d_plot(relative_x:)
        page.driver.with_playwright_page do |browser_page|
          canvas = browser_page.locator(".chatbot-function-plot__canvas[data-dimensions='2']").first
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

      def has_surface?
        page.has_css?(
          ".chatbot-function-plot__canvas[data-dimensions='3'] svg path[fill^='hsl']",
          minimum: 100,
        )
      end

      def rotate_surface
        page.driver.with_playwright_page do |browser_page|
          canvas = browser_page.locator(".chatbot-function-plot__canvas[data-dimensions='3']")
          canvas.scroll_into_view_if_needed
          box = canvas.bounding_box
          browser_page.mouse.move(box["x"] + 200, box["y"] + 150)
          browser_page.mouse.down
          browser_page.mouse.move(box["x"] + 280, box["y"] + 190, steps: 10)
          browser_page.mouse.up
        end
      end

      def surface_path
        find(
          ".chatbot-function-plot__canvas[data-dimensions='3'] svg path[fill^='hsl']",
          match: :first,
        )[
          "d"
        ]
      end

      def zoom_surface(delta_y: -300)
        page.driver.with_playwright_page do |browser_page|
          canvas = browser_page.locator(".chatbot-function-plot__canvas[data-dimensions='3']")
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

      def has_changed_surface?(original_path)
        path =
          find(
            ".chatbot-function-plot__canvas[data-dimensions='3'] svg path[fill^='hsl']",
            match: :first,
          )
        page.has_css?("path[id='#{path[:id]}']:not([d='#{original_path}'])")
      end
    end
  end
end

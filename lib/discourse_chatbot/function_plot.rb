# frozen_string_literal: true

require "dentaku"

module DiscourseChatbot
  class FunctionPlot
    FUNCTIONS = %w[sin cos tan asin acos atan sqrt cbrt abs exp log log10 floor ceil].freeze
    PLOT_TYPES = %w[function implicit parametric polar points polyline vector].freeze
    MAX_FUNCTIONS = 4
    MAX_EXPRESSION_LENGTH = 256
    MAX_TOKENS = 128
    MAX_DEPTH = 16
    MAX_BOUND = 1_000_000

    def self.markdown(args)
      plot_type = args.fetch("plot_type", "function")
      raise ArgumentError if PLOT_TYPES.exclude?(plot_type)

      source = args.fetch("expressions")
      raise ArgumentError if source.length > 6000
      expressions = source.split("\n").map(&:strip).reject(&:empty?)
      title = args.fetch("title", "")
      raise ArgumentError if title.length > 120 || title.match?(/[\r\n]/)

      graph = {
        title: title,
        x_domain: domain(args, "x", [-10, 10]),
        y_domain: domain(args, "y", [-10, 10]),
      }
      graph[:plot_type] = plot_type unless plot_type == "function"
      if %w[points polyline vector].include?(plot_type)
        key = plot_type == "vector" ? :vectors : :points
        limit = plot_type == "vector" ? 16 : 150
        raise ArgumentError if expressions.empty? || expressions.length > limit
        graph[key] = expressions.map do |line|
          values = line.split(",", -1).map(&:strip)
          sizes = plot_type == "vector" ? [2, 4] : [2]
          unless sizes.include?(values.length) &&
                   values.all? { |value|
                     value.match?(/\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?\z/i)
                   }
            raise ArgumentError
          end
          numbers = values.map(&:to_f)
          unless numbers.all? { |value| value.finite? && value.abs <= MAX_BOUND }
            raise ArgumentError
          end
          numbers.unshift(0, 0) if plot_type == "vector" && numbers.length == 2
          numbers
        end
      else
        limit = plot_type == "implicit" ? 2 : MAX_FUNCTIONS
        raise ArgumentError if expressions.empty? || expressions.length > limit
        variables = {
          "function" => %w[x],
          "implicit" => %w[x y],
          "parametric" => %w[t],
          "polar" => %w[theta],
        }.fetch(plot_type)
        graph[:functions] = expressions.map do |expression|
          parts = plot_type == "parametric" ? expression.split(";", -1).map(&:strip) : [expression]
          raise ArgumentError if parts.length != (plot_type == "parametric" ? 2 : 1)
          parts.each { |part| validate_expression!(part, variables + %w[pi e]) }
          plot_type == "parametric" ? parts : expression
        end
        if %w[parametric polar].include?(plot_type)
          graph[:parameter_range] = domain(args, "parameter", [0, 2 * Math::PI])
        end
      end
      "```function-plot\n#{JSON.generate(graph)}\n```"
    end

    def self.validate_expression!(expression, variables)
      if expression.length > MAX_EXPRESSION_LENGTH ||
           !expression.match?(%r{\A[0-9a-z+\-*/^().\s]+\z}i)
        raise ArgumentError
      end
      normalized = expression.downcase
      names = normalized.scan(/[a-z][a-z0-9]*/).reject { |name| name.match?(/\Ae\d+\z/) }
      raise ArgumentError unless (names - FUNCTIONS - variables).empty?

      depth = 0
      normalized.each_char do |character|
        depth += 1 if character == "("
        depth -= 1 if character == ")"
        raise ArgumentError if depth.negative? || depth > MAX_DEPTH
      end
      raise ArgumentError if depth.nonzero?

      calculator = Dentaku::Calculator.new
      calculator.add_function(:floor, :numeric, ->(value) { value.floor })
      calculator.add_function(:ceil, :numeric, ->(value) { value.ceil })
      calculator.add_function(:cbrt, :numeric, ->(value) { Math.cbrt(value) })
      raise ArgumentError if calculator.tokenizer.tokenize(normalized).length > MAX_TOKENS
      node = calculator.ast(normalized)
      raise ArgumentError unless (node.dependencies - variables).empty?
    rescue Dentaku::Error
      raise ArgumentError
    end

    def self.domain(args, axis, default)
      minimum, maximum = args.values_at("#{axis}_min", "#{axis}_max")
      return default if minimum.nil? && maximum.nil?

      unless [minimum, maximum].all? { |value|
               value.is_a?(Numeric) && value.finite? && value.abs <= MAX_BOUND
             } && maximum - minimum >= 0.000001
        raise ArgumentError
      end
      [minimum, maximum]
    end
    private_class_method :domain, :validate_expression!
  end
end

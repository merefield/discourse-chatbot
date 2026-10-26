# frozen_string_literal: true

require "dentaku"

module DiscourseChatbot
  class FunctionPlot
    FUNCTIONS = %w[sin cos tan asin acos atan sqrt abs exp log log10 floor ceil].freeze
    VARIABLES = %w[x pi e].freeze
    MAX_FUNCTIONS = 4
    MAX_EXPRESSION_LENGTH = 256
    MAX_TOKENS = 128
    MAX_DEPTH = 16
    MAX_BOUND = 1_000_000

    def self.markdown(args)
      dimensions = args.fetch("dimensions", 2)
      raise ArgumentError if [2, 3].exclude?(dimensions)
      raise ArgumentError if dimensions == 2 && (args.key?("z_min") || args.key?("z_max"))

      expressions = args.fetch("expressions").split("\n").map(&:strip).reject(&:empty?)
      limit = dimensions == 3 ? 2 : MAX_FUNCTIONS
      raise ArgumentError if expressions.empty? || expressions.length > limit

      variables = dimensions == 3 ? VARIABLES + ["y"] : VARIABLES
      expressions.each { |expression| validate_expression!(expression, variables) }
      title = args.fetch("title", "")
      raise ArgumentError if title.length > 120 || title.match?(/[\r\n]/)

      graph = {
        functions: expressions,
        title: title,
        x_domain: domain(args, "x", [-10, 10]),
        y_domain: domain(args, "y", [-10, 10]),
      }
      if dimensions == 3
        graph[:dimensions] = 3
        graph[:z_domain] = domain(args, "z", [-10, 10])
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

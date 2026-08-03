# frozen_string_literal: true

require "dentaku"

module DiscourseChatbot
  class Calculator
    class InvalidExpression < StandardError
    end

    MAX_EXPRESSION_BYTES = 512
    MAX_TOKENS = 100
    MAX_NESTING_DEPTH = 10
    MAX_NUMERIC_LITERAL_LENGTH = 32
    MAX_RESULT_LENGTH = 1_000
    FORBIDDEN_OPERATORS = %i[pow bitshiftleft bitshiftright].freeze
    ALLOWED_RESULT_TYPES = [Numeric, Date, DateTime, Time, TrueClass, FalseClass].freeze

    def self.evaluate(expression, now: Time.current)
      new(expression, now:).evaluate
    end

    def initialize(expression, now:)
      @expression = expression
      @now = now.respond_to?(:to_time) ? now.to_time : now
      @calculator = Dentaku::Calculator.new
    end

    def evaluate
      expression = validated_expression

      result =
        @calculator.disable_cache do |calculator|
          calculator.evaluate!(expression, pi: Math::PI, e: Math::E, now: @now)
        end

      validate_result!(result)
      result
    rescue Dentaku::Error, ArgumentError, RangeError, ZeroDivisionError => error
      raise InvalidExpression, error.message
    end

    private

    def validated_expression
      if !@expression.is_a?(String) || @expression.blank? || !@expression.valid_encoding?
        raise InvalidExpression, "The expression must be a valid non-empty string"
      end

      if @expression.bytesize > MAX_EXPRESSION_BYTES
        raise InvalidExpression, "The expression is too long"
      end

      expression = normalize_expression(@expression)
      tokens = @calculator.tokenizer.tokenize(expression)
      raise InvalidExpression, "The expression is too complex" if tokens.length > MAX_TOKENS

      validate_tokens!(tokens)
      expression
    end

    def normalize_expression(expression)
      expression.gsub(/\bMath(?:::|\.)PI\b/i, "PI").gsub(/\bMath(?:::|\.)E\b/i, "E").gsub("π", "PI")
    end

    def validate_tokens!(tokens)
      nesting_depth = 0

      tokens.each do |token|
        if forbidden_operator?(token)
          raise InvalidExpression, "The expression uses an unsupported operator"
        end

        if oversized_numeric_literal?(token)
          raise InvalidExpression, "The expression contains an oversized number"
        end

        nesting_depth += nesting_change(token)
        if nesting_depth > MAX_NESTING_DEPTH
          raise InvalidExpression, "The expression is nested too deeply"
        end
      end
    end

    def forbidden_operator?(token)
      token.category == :operator && FORBIDDEN_OPERATORS.include?(token.value)
    end

    def oversized_numeric_literal?(token)
      return false unless token.category == :numeric

      token.raw_value.to_s.count("0-9A-Fa-f") > MAX_NUMERIC_LITERAL_LENGTH
    end

    def nesting_change(token)
      return 1 if token.category == :grouping && token.value == :open
      return 1 if token.category == :array && token.value == :array_start
      return 1 if token.category == :access && token.value == :lbracket
      return -1 if token.category == :grouping && token.value == :close
      return -1 if token.category == :array && token.value == :array_end
      return -1 if token.category == :access && token.value == :rbracket

      0
    end

    def validate_result!(result)
      unless ALLOWED_RESULT_TYPES.any? { |type| result.is_a?(type) }
        raise InvalidExpression, "The expression returned an unsupported result"
      end

      if result.respond_to?(:finite?) && !result.finite?
        raise InvalidExpression, "The expression returned a non-finite result"
      end

      if result.to_s.length > MAX_RESULT_LENGTH
        raise InvalidExpression, "The expression result is too long"
      end
    end
  end
end

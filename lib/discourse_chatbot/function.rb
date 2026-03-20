# frozen_string_literal: true

module ::DiscourseChatbot
  class Function

    def name
      raise "Overwrite me!"
    end

    def description
      raise "Overwrite me!"
    end

    def parameters
      raise "Overwrite me!"
    end

    def required
      raise "Overwrite me!"
    end

    def initialize
      @name = name
      @description = description
      @parameters = parameters
      @required = required
    end

    def process(args)
      validate_parameters(args)
    end

    private

    def validate_parameters(args)
      if args.count < @required.length
        raise ArgumentError, "Expected at least #{@required.length} arguments, but got #{args.length}"
      end

      @required.each do |required|
        if !args.has_key?(required)
          raise ArgumentError, "Expected '#{required}' to be included in the arguments because it is required, but is missing"
        end
      end

      args.each do |arg|
        parameter = @parameters.find { |param| param[:name] == arg[0] }

        if parameter.nil?
          raise ArgumentError, "Unexpected argument '#{arg[0]}'"
        end

        unless arg[1].is_a?(parameter[:type])
          raise ArgumentError, "Argument '#{arg[0]}' should be of type #{parameter[:type]}"
        end

        if parameter[:enum].present? && !parameter[:enum].include?(arg[1])
          raise ArgumentError, "Argument '#{arg[0]}' should be one of #{parameter[:enum].join(", ")}"
        end
      end

      true
    end
  end
end

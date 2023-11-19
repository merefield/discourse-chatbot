# frozen_string_literal: true

module ::DiscourseChatbot
  class Function
    attr_reader :name, :description, :parameters, :required

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

    def validate_parameters(*args)
      unless args.length >= @required.length
        raise ArgumentError, "Expected at least #{@required.length} arguments, but got #{args.length}"
      end

      @required.each do |required|
        if !args.find { |arg| required == arg.each_key.first }
          raise ArgumentError, "Expected '#{required}' to be included in the arguments because it is required, but is missing"
        end
      end

      args.each do |arg|
        unless arg.values[0].is_a?(@parameters.find { |param| param[:name] == arg.each_key.first }[:type])
          raise ArgumentError, "Argument #{index + 1} should be of type #{parameter[:type]}"
        end
      end

      true
    end
  end
end

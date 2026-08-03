# frozen_string_literal: true

module ::DiscourseChatbot
  class Tool
    BUILT_IN_TOOL_NAMES = %w[
      calculate
      escalate_to_staff
      local_forum_search
      news
      paint_edit_picture
      paint_picture
      remaining_bot_quota
      stock_data
      user_information
      vision
      web_crawler
      web_search
      wikipedia
    ]

    def self.choices
      BUILT_IN_TOOL_NAMES.sort
    end

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
        raise ArgumentError,
              "Expected at least #{@required.length} arguments, but got #{args.length}"
      end

      @required.each do |required|
        if !args.has_key?(required)
          raise ArgumentError,
                "Expected '#{required}' to be included in the arguments because it is required, but is missing"
        end
      end

      args.each do |arg|
        parameter = @parameters.find { |param| param[:name] == arg[0] }

        raise ArgumentError, "Unexpected argument '#{arg[0]}'" if parameter.nil?

        unless arg[1].is_a?(parameter[:type])
          raise ArgumentError, "Argument '#{arg[0]}' should be of type #{parameter[:type]}"
        end

        if parameter[:enum].present? && !parameter[:enum].include?(arg[1])
          raise ArgumentError,
                "Argument '#{arg[0]}' should be one of #{parameter[:enum].join(", ")}"
        end
      end

      true
    end
  end
end

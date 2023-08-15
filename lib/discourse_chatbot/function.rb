require 'byebug'

module ::DiscourseChatbot
  class Function
    # attr_reader :name, :description, :parameters

    def name
      raise "Overwrite me!"
    end

    def description
      raise "Overwrite me!"
    end

    def parameters
      raise "Overwrite me!"
    end

    def initialize
      @name = name
      @description = description
      @parameters = parameters
      # @process_block = block
    end
  
    def process(*args)
      validate_parameters(*args)
    end
  
    private
  
    def validate_parameters(*args)
      unless args.length == @parameters.length
        raise ArgumentError, "Expected #{@parameters.length} arguments, but got #{args.length}"
      end

      @parameters.each_with_index do |parameter, index|
        unless args[index].is_a?(parameter[:type])
          raise ArgumentError, "Argument #{index + 1} should be of type #{parameter[:type]}"
        end
        # unless args[index].
      end
    end
  end
end
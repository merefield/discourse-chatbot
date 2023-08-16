# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class CalculatorFunction < Function

    def name
      'calculate'
    end

    def description
      <<~EOS 
        Useful for getting the result of a math expression.  It is a general purpose calculator.  It works with Ruby expressions.

        You can retrieve the current date from it too and using the core Ruby Time method to calculate dates.

        The input to this tool should be a valid mathematical expression that could be executed by the base Ruby programming language with no extensions.

        Be certain to prefix any functions with 'Math.'
        Usage:
          Action Input: 1 + 1
          Action Input: 3 * 2 / 4
          Action Input: 9 - 7
          Action Input: Time.now - 2 * 24 * 60 * 60
          Action Input: Math.cbrt(13) + Math.cbrt(12)
          Action Input: Math.sqrt(8)
          Action Input: (4.1 + 2.3) / (2.0 - 5.6) * 3"
      EOS
    end
    
    def parameters
      [
        { name: "input", type: String, description: "the mathematical expression you need to process and get the answer to. Make sure it is Ruby compatible." } ,
      ]
    end

    def required
      ['input']
    end

    def process(args)
      begin
        super(args)

        SafeRuby.eval(args[parameters[0][:name]], timeout: 5)
      rescue 
        "\"#{args[parameters[0][:name]]}\" is an invalid mathematical expression, make sure if you are trying to calculate dates use Ruby Time class"
      end
    end
  end
end

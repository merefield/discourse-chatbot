# frozen_string_literal: true

require_relative '../function'
require 'eqn'

module DiscourseChatbot
  class CalculatorFunction < Function

    def name
    'calculate'
    end

    def description
      <<~EOS 
        Useful for getting the result of a math expression.  It is a general purpose calculator.

        The input to this tool should be a valid mathematical expression that could be executed by a simple calculator.
        Usage:
          Action Input: 1 + 1
          Action Input: 3 * 2 / 4
          Action Input: 9 - 7
          Action Input: (4.1 + 2.3) / (2.0 - 5.6) * 3"
      EOS
    end
    
    def parameters
      [
        { name: "input", type: String, description: "the mathematical expression you need to process and get the answer to" } ,
      ]
    end 

    def process(*args)
      begin
        #super(*args)
        Eqn::Calculator.calc(*args[0])
      rescue Eqn::ParseError, Eqn::NoVariableValueError
        "\"#{input}\" is an invalid mathematical expression"
      end
    end
  end
end

# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class TodaysDateFunction < Function

    def name
      'todays_date'
    end
    
    def description
      <<~EOS
        You don't know today's date but this function will tell you.

        It doesn't take any parameters, but just returns todays date.
      EOS
    end

    def parameters
      []
    end

    def process(*args)
      begin
        d = DateTime.now
        d.strftime("%Y-%m-%d")
      rescue
        "ERROR: Had trouble returning the date"
      end
    end
  end
end
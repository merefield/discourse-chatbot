# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class GetDistanceBetweenLocationsFunction < Function

    REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"

    def name
      'get_distance_between_locations'
    end

    def description
      I18n.t("chatbot.prompt.function.get_distance_between_locations.description")
    end
    
    def parameters
      [
        { name: "coords1", type: String, description: I18n.t("chatbot.prompt.function.get_distance_between_locations.parameters.coords") } ,
        { name: "coords2", type: String, description: I18n.t("chatbot.prompt.function.get_distance_between_locations.parameters.coords") } ,
      ]
    end

    def required
      ['coords1', 'coords2']
    end

    def process(args)
      begin
        super(args)
        query1 = args[parameters[0][:name]]
        query2 = args[parameters[1][:name]]

        coords1 = query1.split(",")
        coords2 = query2.split(",")


        #byebug
        distance = ::Locations::Geocode.return_distance(coords1[0], coords1[1], coords2[0], coords2[1])

        I18n.t("chatbot.prompt.function.get_distance_between_locations.answer_summary", distance: distance, coords1: coords1, coords2: coords2)
      rescue
        I18n.t("chatbot.prompt.function.get_distance_between_locations.error", query: args[parameters[0][:name]])
      end
    end
  end
end


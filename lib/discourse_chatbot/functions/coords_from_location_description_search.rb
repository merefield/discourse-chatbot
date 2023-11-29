# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class GetCoordsOfLocationDescriptionFunction < Function
    def name
      'return_coords_from_location_description'
    end

    def description
      I18n.t("chatbot.prompt.function.return_coords_from_location_description.description")
    end
    
    def parameters
      [
        { name: "query", type: String, description: I18n.t("chatbot.prompt.function.return_coords_from_location_description.parameters.coords") } ,
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]

        results = []

        if !query.blank?
          coords = ::Locations::Geocode.return_coords(query)
        end

        response = I18n.t("chatbot.prompt.function.return_coords_from_location_description.answer_summary", query: query, coords: coords)

        response
      rescue
        I18n.t("chatbot.prompt.function.return_coords_from_location_description.error", query: args[parameters[0][:name]])
      end
    end
  end
end

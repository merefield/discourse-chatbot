# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class GetDistanceBetweenLocationsFunction < ::DiscourseChatbot::Function
      def name
        "get_distance_between_locations"
      end

      def description
        I18n.t("chatbot.prompt.function.get_distance_between_locations.description")
      end

      def parameters
        [
          {
            name: "coords1",
            type: String,
            description:
              I18n.t("chatbot.prompt.function.get_distance_between_locations.parameters.coords"),
          },
          {
            name: "coords2",
            type: String,
            description:
              I18n.t("chatbot.prompt.function.get_distance_between_locations.parameters.coords"),
          },
        ]
      end

      def required
        %w[coords1 coords2]
      end

      def process(args)
        begin
          super(args)
          query1 = args[parameters[0][:name]]
          query2 = args[parameters[1][:name]]

          coords1 = query1.split(",")
          coords2 = query2.split(",")

          distance =
            ::Locations::Geocode.return_distance(coords1[0], coords1[1], coords2[0], coords2[1])

          {
            answer:
              I18n.t(
                "chatbot.prompt.function.get_distance_between_locations.answer_summary",
                distance: distance,
                coords1: coords1,
                coords2: coords2,
              ),
            token_usage: 0,
          }
        rescue StandardError
          {
            answer:
              I18n.t(
                "chatbot.prompt.function.get_distance_between_locations.error",
                query: args[parameters[0][:name]],
              ),
            token_usage: 0,
          }
        end
      end
    end
  end
end

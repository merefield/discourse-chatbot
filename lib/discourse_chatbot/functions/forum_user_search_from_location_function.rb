# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class ForumUserSearchFromLocationFunction < ::DiscourseChatbot::Function
      def name
        "forum_user_search_from_location"
      end

      def description
        I18n.t("chatbot.prompt.function.forum_user_search_from_location.description")
      end

      def parameters
        [
          {
            name: "coords",
            type: String,
            description:
              I18n.t("chatbot.prompt.function.forum_user_search_from_location.parameters.coords"),
          },
          {
            name: "distance",
            type: Integer,
            description:
              I18n.t("chatbot.prompt.function.forum_user_search_from_location.parameters.distance"),
          },
          {
            name: "number_of_users",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_location.parameters.number_of_users",
              ),
          },
        ]
      end

      def required
        ["coords"]
      end

      def process(args)
        begin
          super(args)
          query = args[parameters[0][:name]]
          distance = args[parameters[1][:name]].presence || 5000
          number_of_users = args[parameters[2][:name]].presence || 3
          number_of_users = number_of_users > 16 ? 16 : number_of_users
          results = []

          coords = query.split(/,/)
          results =
            ::Locations::UserLocationProcess.search_users_from_location(
              coords[0],
              coords[1],
              distance,
            )
          response =
            I18n.t(
              "chatbot.prompt.function.forum_user_search_from_location.answer_summary",
              distance: distance,
              query: query,
            )

          results.each_with_index do |result, index|
            user = User.find(result)
            user_location = ::Locations::UserLocation.find_by(user_id: user.id)
            distance = user_location.distance_from([coords[0], coords[1]], :km) # geocoder expects order lat, lon.
            response +=
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_location.answer",
                username: user.username,
                distance: distance,
                rank: index + 1,
              )
            break if index == number_of_users
          end
          { answer: response, token_usage: 0 }
        rescue StandardError
          {
            answer:
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_location.error",
                query: args[parameters[0][:name]],
              ),
            token_usage: 0,
          }
        end
      end
    end
  end
end

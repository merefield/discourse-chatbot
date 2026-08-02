# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class ForumUserSearchFromTopicLocationFunction < ::DiscourseChatbot::Function
      def name
        "forum_user_search_from_topic_location"
      end

      def description
        I18n.t("chatbot.prompt.function.forum_user_search_from_topic_location.description")
      end

      def parameters
        [
          {
            name: "topic_id",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_topic_location.parameters.topic_id",
              ),
          },
          {
            name: "distance",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_topic_location.parameters.distance",
              ),
          },
          {
            name: "number_of_users",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_topic_location.parameters.number_of_users",
              ),
          },
        ]
      end

      def required
        ["topic_id"]
      end

      def process(args)
        begin
          super(args)
          topic_id = args[parameters[0][:name]]

          distance = args[parameters[1][:name]].presence || 500
          number_of_users = args[parameters[2][:name]].presence || 3
          number_of_users = number_of_users > 16 ? 16 : number_of_users

          target_topic_location = ::Locations::TopicLocation.find_by(topic_id: topic_id)
          user_ids =
            ::Locations::UserLocationProcess.search_users_from_topic_location(topic_id, distance)

          response =
            I18n.t(
              "chatbot.prompt.function.forum_user_search_from_topic_location.answer_summary",
              distance: distance,
              query: topic_id,
            )

          user_ids
            .first(number_of_users)
            .each_with_index do |user_id, index|
              user = ::User.find(user_id)
              user_location = ::Locations::UserLocation.find_by(user_id: user.id)
              result_distance =
                user_location.distance_from(target_topic_location.to_coordinates, :km)
              response +=
                I18n.t(
                  "chatbot.prompt.function.forum_user_search_from_topic_location.answer",
                  username: user.username,
                  distance: result_distance,
                  rank: index + 1,
                )
            end
          { answer: response, token_usage: 0 }
        rescue StandardError
          {
            answer:
              I18n.t(
                "chatbot.prompt.function.forum_user_search_from_topic_location.error",
                query: args[parameters[0][:name]],
              ),
            token_usage: 0,
          }
        end
      end
    end
  end
end

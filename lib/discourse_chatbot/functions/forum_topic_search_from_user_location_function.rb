# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class ForumTopicSearchFromUserLocationFunction < ::DiscourseChatbot::Function
      REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"

      def name
        "forum_topic_search_from_user_location"
      end

      def description
        I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.description")
      end

      def parameters
        [
          {
            name: "username",
            type: String,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_user_location.parameters.username",
              ),
          },
          {
            name: "distance",
            type: String,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_user_location.parameters.distance",
              ),
          },
          {
            name: "number_of_topics",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_user_location.parameters.number_of_topics",
              ),
          },
        ]
      end

      def required
        ["username"]
      end

      def process(args)
        begin
          super(args)
          query = args[parameters[0][:name]]

          distance = args[parameters[1][:name]].presence || 500
          number_of_topics = args[parameters[2][:name]].presence || 3
          number_of_topics = number_of_topics > 16 ? 16 : number_of_topics

          user_id = ::User.find_by(username: query).id
          target_user_location = ::Locations::UserLocation.find_by(user_id: user_id)
          topic_ids =
            ::Locations::UserLocationProcess.search_topics_from_user_location(user_id, distance)

          response =
            I18n.t(
              "chatbot.prompt.function.forum_topic_search_from_user_location.answer_summary",
              distance: distance,
              query: query,
            )

          topic_ids
            .first(number_of_topics)
            .each_with_index do |topic_id, index|
              topic = ::Topic.find(topic_id)
              url = "https://#{Discourse.current_hostname}/t/slug/#{topic.id}"
              topic_location = ::Locations::TopicLocation.find_by(topic_id: topic.id)
              result_distance =
                topic_location.distance_from(target_user_location.to_coordinates, :km)
              response +=
                I18n.t(
                  "chatbot.prompt.function.forum_topic_search_from_user_location.answer",
                  title: topic.title,
                  address: topic_location.address,
                  url: url,
                  distance: result_distance,
                  rank: index + 1,
                )
            end
          { answer: response, token_usage: 0 }
        rescue StandardError
          {
            answer:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_user_location.error",
                query: args[parameters[0][:name]],
              ),
            token_usage: 0,
          }
        end
      end
    end
  end
end

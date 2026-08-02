# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class ForumTopicSearchFromTopicLocationFunction < ::DiscourseChatbot::Function
      def name
        "forum_topic_search_from_topic_location"
      end

      def description
        I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.description")
      end

      def parameters
        [
          {
            name: "topic_id",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_topic_location.parameters.topic_id",
              ),
          },
          {
            name: "distance",
            type: String,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_topic_location.parameters.distance",
              ),
          },
          {
            name: "number_of_topics",
            type: Integer,
            description:
              I18n.t(
                "chatbot.prompt.function.forum_topic_search_from_topic_location.parameters.number_of_topics",
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
          number_of_topics = args[parameters[2][:name]].presence || 3
          number_of_topics = number_of_topics > 16 ? 16 : number_of_topics

          target_topic_location = ::Locations::TopicLocation.find_by(topic_id: topic_id)
          topic_ids =
            ::Locations::TopicLocationProcess.search_topics_from_topic_location(topic_id, distance)

          response =
            I18n.t(
              "chatbot.prompt.function.forum_topic_search_from_topic_location.answer_summary",
              distance: distance,
              query: topic_id,
            )

          topic_ids
            .first(number_of_topics)
            .each_with_index do |nearby_topic_id, index|
              topic = ::Topic.find(nearby_topic_id)
              url = "https://#{Discourse.current_hostname}/t/slug/#{topic.id}"
              topic_location = ::Locations::TopicLocation.find_by(topic_id: topic.id)
              result_distance =
                topic_location.distance_from(target_topic_location.to_coordinates, :km)
              response +=
                I18n.t(
                  "chatbot.prompt.function.forum_topic_search_from_topic_location.answer",
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
                "chatbot.prompt.function.forum_topic_search_from_topic_location.error",
                query: args[parameters[0][:name]],
              ),
            token_usage: 0,
          }
        end
      end
    end
  end
end

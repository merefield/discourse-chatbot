# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumUserSearchFromTopicLocationFunction < Function

    REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"

    def name
      'forum_topic_search_from_user_location'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.description")
    end

    def parameters
      [
        { name: "username", type: String, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.parameters.username") } ,
        { name: "distance", type: Integer, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.parameters.distance") } ,
        { name: "number_of_topics", type: Integer, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.parameters.number_of_topics") }
      ]
    end

    def required
      ['username']
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]

        distance = args[parameters[1][:name]].blank? ? 500 : args[parameters[1][:name]]
        number_of_topics = args[parameters[2][:name]].blank? ? 3 : args[parameters[2][:name]]
        number_of_topics = number_of_topics > 16 ? 16 : number_of_topics

        results = []

        target_topic_location = TopicLocation.find_by(topic_id: topic_id)
        user_id = User.find_by(username: query).id
        results = ::Locations::TopicLocationProcess.search_from_user_location(user_id, distance)

        response = I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.answer_summary", distance: distance, query: query)

        results.each_with_index do |result, index|
          user = User.find(result)
          user_location = ::Locations::UserLocation.find_by(user_id: user.id)
          distance = user_location.distance_from(target_topic_location.to_coordinates, :km)
          response += I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.answer", username: user.username, distance: distance, rank: index + 1)
          break if index == number_of_users
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_topic_search_from_user_location.error", query: args[parameters[0][:name]])
      end
    end
  end
end

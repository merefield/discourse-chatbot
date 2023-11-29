# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumTopicSearchFromTopicLocationFunction < Function

    REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"

    def name
      'forum_topic_search_from_topic_location'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.description")
    end
    
    def parameters
      [
        { name: "topic_id", type: Integer, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.parameters.username") } ,
        { name: "distance", type: String, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.parameters.distance") } ,
        { name: "number_of_topics", type: Integer, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.parameters.number_of_users") }
      ]
    end

    def required
      ['topic_id']
    end

    def process(args)
      begin
        #TODO placeholder, non-functioning
        super(args)
        query = args[parameters[0][:name]]

        distance = args[parameters[1][:name]].blank? ? 500 : args[parameters[1][:name]]
        number_of_topics = args[parameters[2][:name]].blank? ? 3 : args[parameters[2][:name]]
        number_of_topics = number_of_topics > 16 ? 16 : number_of_users

        results = []

        # user_id = User.find_by(username: query).id
        target_topic_location = TopicLocation.find_by(topic_id: topic.id)
        results = ::Locations::TopicLocationProcess.search_from_topic_location(topic_id, distance)

        response = I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.answer_summary", distance: distance, query: query)

        results.each_with_index do |result, index|
          topic = Topic.find(result.topic_id)
          url = "https://#{Discourse.current_hostname}/t/slug/#{topic.topic_id}"
          topic_location = ::Locations::TopicLocation.find_by(topic_id: topic.id)
          distance = result.distance_from(target_topic_location.to_coordinates, :km)
          response += I18n.t("chatbot.prompt.function.forum_topic_search_from_topic_location.answer", title: topic.title, address: topic_location.address, url: url, distance: distance, rank: index + 1)
          break if index == number_of_topics
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.error", query: args[parameters[0][:name]])
      end
    end
  end
end

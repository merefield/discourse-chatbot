# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumTopicSearchFromLocationFunction < Function

    def name
      'forum_topic_search_from_location'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_topic_search_from_location.description")
    end

    def parameters
      [
        { name: "coords", type: String, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_location.parameters.coords") } ,
        { name: "distance", type: String, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_location.parameters.distance") } ,
        { name: "number_of_topics", type: Integer, description: I18n.t("chatbot.prompt.function.forum_topic_search_from_location.parameters.number_of_topics") }
      ]
    end

    def required
      ['coords']
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]
        distance = args[parameters[1][:name]].blank ? 500 : args[parameters[1][:name]]
        number_of_topics = args[parameters[2][:name]].blank? ? 3 : args[parameters[2][:name]]
        number_of_topics = number_of_topics > 16 ? 16 : number_of_topics

        results = []

        coords = query.split(/\D+/).reject(&:empty?).map(&:to_i)
        results = ::Locations::TopicLocationProcess.search_from_location(coords[0], coords[1], distance)

        response = I18n.t("chatbot.prompt.function.forum_topic_search_from_location.answer_summary", distance: distance, query: query)

        results.each_with_index do |result, index|
          topic = Topic.find(result.topic_id)
          url = "https://#{Discourse.current_hostname}/t/slug/#{topic.topic_id}"
          topic_location = TopicLocation.find_by(topic_id: topic.id)
          distance = result.distance_from(coords[1], coords[0], :km) # geocoder expects order lat, lon.
          response += I18n.t("chatbot.prompt.function.forum_topic_search_from_location.answer", title: topic.title, address: topic_location.address, url: url, distance: distance, rank: index + 1)
          break if index == number_of_topics
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_topic_search_from_location.error", query: args[parameters[0][:name]])
      end
    end
  end
end

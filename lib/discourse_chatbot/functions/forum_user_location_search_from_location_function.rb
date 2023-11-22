# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumUserLocationSearchFromLocationFunction < Function

    ALT_REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"
    REGEX_PATTERN = "^[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)$"

    def name
      'local_forum_user_location_search_from_location'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.description")
    end
    
    def parameters
      [
        { name: "coords", type: String, description: I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.parameters.coords") } ,
        { name: "distance", type: String, description: I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.parameters.distance") } ,
        { name: "number_of_users", type: Integer, description: I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.parameters.number_of_users") }
      ]
    end

    def required
      ['coords']
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]
        distance = args[parameters[1][:name]].blank? ? 5000 : args[parameters[1][:name]]
        number_of_users = args[parameters[2][:name]].blank? ? 3 : args[parameters[2][:name]]
        number_of_users = number_of_users > 16 ? 16 : number_of_users

        results = []

        if query.match?(/^[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)$/)
          coords = query.split(/, /).reject(&:empty?).map(&:to_i)
          results = ::Locations::UserLocationProcess.search_from_location(coords[0], coords[1], distance)
        end

        response = I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.answer_summary", distance: distance, query: query)

        results.each_with_index do |result, index|
          user = User.find(result)
          response += I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.answer", username: user.username, rank: index + 1)
          break if index == number_of_users
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_user_location_search_from_location.error", query: args[parameters[0][:name]])
      end
    end
  end
end

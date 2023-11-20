# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumUserLocationSearchFromUserFunction < Function

    REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"

    def name
      'local_forum_user_location_search_from_user'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.description")
    end
    
    def parameters
      [
        { name: "username", type: String, description: I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.parameters.username") } ,
        { name: "distance", type: String, description: I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.parameters.distance") } ,
        { name: "number_of_users", type: Integer, description: I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.parameters.number_of_users") }
      ]
    end

    def required
      ['username']
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]
        distance = args[parameters[1][:name]].blank ? 500 : args[parameters[1][:name]]
        number_of_users = args[parameters[2][:name]].blank? ? 3 : args[parameters[2][:name]]
        number_of_users = number_of_users > 16 ? 16 : number_of_users

        results = []

        user_id = User.find_by(username: query).id
        results = ::Locations::UserLocationProcess.search_from_user_location(user_id, distance)

        response = I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.answer_summary", distance: distance, query: query)

        results.each_with_index do |result, index|
          user = User.find(result)
          response += I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.answer", username: user.username, rank: index + 1)
          break if index == number_of_users
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_user_location_search_from_user.error", query: args[parameters[0][:name]])
      end
    end
  end
end

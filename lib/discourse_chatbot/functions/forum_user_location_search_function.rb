# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumUserLocationSearchFunction < Function

    REGEX_PATTERN = "(\[)?-?\d*.?\d*,\s?-?\d*.?\d*(\])?"

    def name
      'local_forum_user_location_search'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_user_location_search.description")
    end
    
    def parameters
      [
        { name: "username", type: String, description: I18n.t("chatbot.prompt.function.forum_user_location_search.parameters.username") } ,
        { name: "coords", type: String, description: I18n.t("chatbot.prompt.function.forum_user_location_search.parameters.coords") } ,
        { name: "number_of_users", type: Integer, description: I18n.t("chatbot.prompt.function.forum_user_location_search.parameters.number_of_users") }
      ]
    end

    def required
      []
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]
        number_of_users = args[parameters[2][:name]].blank? ? 3 : args[parameters[2][:name]]
        number_of_users = number_of_users > 16 ? 16 : number_of_users

        results = []

        if REGEX_PATTERN.match?(query)
          coords = query.split(/\D+/).reject(&:empty?).map(&:to_i)
          results = ::Locations::UserLocationProcess.search_from_location(coords[0], coords[1])
        else
          user_id = User.find_by(username: query).id
          results = ::Locations::UserLocationProcess.search_from_user_location(user_id)
        end

        response = I18n.t("chatbot.prompt.function.forum_user_location_search.answer_summary", number_of_users: number_of_users)

        results.each_with_index do |result, index|
          response += I18n.t("chatbot.prompt.function.forum_user_location_search.answer", username: result.username, rank: index + 1)
          break if index == number_of_users
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_user_location_search.error", query: args[parameters[0][:name]])
      end
    end
  end
end

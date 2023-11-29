# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumUserDistanceFromLocationFunction < Function

    def name
      'forum_user_distance_from_location'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_user_distance_from_location.description")
    end
    
    def parameters
      [
        { name: "username", type: String, description: I18n.t("chatbot.prompt.function.forum_user_distance_from_location.parameters.username") } ,
        { name: "coords", type: String, description: I18n.t("chatbot.prompt.function.forum_user_distance_from_location.parameters.coords") }
      ]
    end

    def required
      ['username', 'coords']
    end

    def process(args)
      begin
        super(args)

        username = args[parameters[0][:name]]
        location = args[parameters[1][:name]]

        if location.match?(/^[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)$/)
          coords = location.split(/, /).reject(&:empty?).map(&:to_i)
          result = ::Locations::UserLocationProcess.get_user_distance_from_location(username, coords[0], coords[1])
        end

        response = I18n.t("chatbot.prompt.function.forum_user_distance_from_location.answer_summary", distance: result, username: username, coords: location)

        response
      rescue
        I18n.t("chatbot.prompt.function.forum_user_distance_from_location.error")
      end
    end
  end
end
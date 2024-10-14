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

        coords = location.split(/, /)
        user = User.find_by(username: username)
        result = ::Locations::UserLocationProcess.get_user_distance_from_location(user.id, coords[0], coords[1])

        response = I18n.t("chatbot.prompt.function.forum_user_distance_from_location.answer_summary", distance: result, username: username, coords: location)

        {
          answer: response,
          token_usage: 0
        }
      rescue
        {
          answer: I18n.t("chatbot.prompt.function.forum_user_distance_from_location.error"),
          token_usage: 0
        }
      end
    end
  end
end

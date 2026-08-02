# frozen_string_literal: true

module DiscourseChatbot
  module Functions
    class ForumGetUserAddressFunction < ::DiscourseChatbot::Function
      def name
        "forum_get_user_address"
      end

      def description
        I18n.t("chatbot.prompt.function.forum_get_user_address.description")
      end

      def parameters
        [
          {
            name: "username",
            type: String,
            description:
              I18n.t("chatbot.prompt.function.forum_get_user_address.parameters.username"),
          },
        ]
      end

      def required
        ["username"]
      end

      def process(args)
        begin
          super(args)

          username = args[parameters[0][:name]]

          user = User.find_by(username_lower: username.downcase)
          result = ::Locations::UserLocation.find_by(user_id: user.id)

          response =
            I18n.t(
              "chatbot.prompt.function.forum_get_user_address.answer_summary",
              username: username,
              address: result.address,
              latitude: result.latitude,
              longitude: result.longitude,
            )

          { answer: response, token_usage: 0 }
        rescue StandardError
          { answer: I18n.t("chatbot.prompt.function.forum_get_user_address.error"), token_usage: 0 }
        end
      end
    end
  end
end

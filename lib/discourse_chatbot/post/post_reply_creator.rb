# frozen_string_literal: true
module ::DiscourseChatbot
  class PostReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
      ::DiscourseChatbot.progress_debug_message("5. Creating a new Post...")

        default_opts = {
          raw: @message_body,
          topic_id: @topic_or_channel_id,
          post_alert_options: { skip_send_email: true },
          skip_validations: true
        }

        default_opts.merge!(reply_to_post_number: @reply_to_post_number) unless SiteSetting.chatbot_can_trigger_from_whisper

        begin
          new_post = PostCreator.create!(@author, default_opts)

          presence = PresenceChannel.new("/discourse-presence/reply/#{@topic_or_channel_id}")
          presence.leave(user_id:  @author.id, client_id: "12345")

          ::DiscourseChatbot.progress_debug_message("6. The Post has been created successfully")
        rescue => e
          ::DiscourseChatbot.progress_debug_message("Problem with the bot Post: #{e}")
          Rails.logger.error ("AI Bot: There was a problem: #{e}")
        end
    end
  end
end

# frozen_string_literal: true
module ::DiscourseChatbot
  class PostReplyCreator < ReplyCreator

    def initialize(options = {})
      super(options)
    end

    def create
      ::DiscourseChatbot.progress_debug_message("5. Creating a new Post...")

      begin
        default_opts = {
          topic_id: @topic_or_channel_id,
          post_alert_options: { skip_send_email: true },
          skip_validations: true
        }

        if @is_private_msg && @human_participants_count == 1
          latest_post_id = ::Topic.find(@topic_or_channel_id).posts.order('created_at DESC').first.id

          if @reply_to != latest_post_id
            ::DiscourseChatbot.progress_debug_message("7. The Post was discarded as there is a newer human message")
            # do not create a new response if the message is not the latest
            return
          end
        end

        if @chatbot_bot_type == "RAG" && SiteSetting.chatbot_include_inner_thoughts_in_private_messages && @is_private_msg
          default_opts.merge!(raw: '[details="Inner Thoughts"]<br/>' + @inner_thoughts + '<br/>[/details]')

          new_post = PostCreator.create!(@author, default_opts)
        end

        default_opts.merge!(reply_to_post_number: @reply_to_post_number) unless SiteSetting.chatbot_can_trigger_from_whisper
        default_opts.merge!(raw: @message_body)

        new_post = PostCreator.create!(@author, default_opts)

        is_private_msg = new_post.topic.private_message?

        begin
          presence = PresenceChannel.new("/discourse-presence/reply/#{@topic_or_channel_id}")
          presence.leave(user_id: @author.id, client_id: "12345")
        rescue
          # ignore issues with permissions related to communicating presence
        end

        ::DiscourseChatbot.progress_debug_message("6. The Post has been created successfully")
      rescue => e
        ::DiscourseChatbot.progress_debug_message("Problem with the bot Post: #{e}")
        Rails.logger.error("Chatbot: There was a problem: #{e}")
      end
    end
  end
end

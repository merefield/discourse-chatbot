# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class EscalateToStaffFunction < Function

    def name
      'escalate_to_staff'
    end

    def description
      I18n.t("chatbot.prompt.function.escalate_to_staff.description")
    end

    def parameters
      []
    end

    def required
      []
    end

    def process(args, opts)
      begin
        super(args)

        return I18n.t("chatbot.prompt.function.escalate_to_staff.wrong_type_error") if opts[:type] != ::DiscourseChatbot::MESSAGE

        channel_id = opts[:topic_or_channel_id]
        channel = ::Chat::Channel.find(channel_id)

        current_user = User.find(opts[:user_id])
        bot_user = User.find(opts[:bot_user_id])
        target_usernames = [current_user.username, bot_user.username].join(",")

        target_group_names = []

        Array(SiteSetting.chatbot_escalate_to_staff_groups).each do |g|
          target_group_names << Group.find(g.to_i).name
        end

        target_group_names = target_group_names.join(",")

        message_or_post_id = opts[:reply_to_message_or_post_id]

        current_message = ::Chat::Message.find(message_or_post_id)

        message_collection = []
  
        message_collection << current_message
  
        collect_amount = SiteSetting.chatbot_escalate_to_staff_max_history
  
        while message_collection.length < collect_amount do
          prior_message = ::Chat::Message.where(chat_channel_id: current_message.chat_channel_id, deleted_at: nil).where('chat_messages.id < ?', current_message.id).last
          if prior_message.nil?
            break
          else
            current_message = prior_message
          end
          message_collection << current_message
        end

        content = generate_transcript(message_collection, bot_user)

        default_opts = {
          post_alert_options: { skip_send_email: true },
          raw: I18n.t("chatbot.prompt.function.escalate_to_staff.announcement", content: content),
          skip_validations: true,
          title: I18n.t("chatbot.prompt.function.escalate_to_staff.title"),
          archetype: Archetype.private_message,
          target_usernames: target_usernames,
          target_group_names: target_group_names
        }

        posting_user = SiteSetting.chatbot_escalate_to_staff_user_author ? current_user : bot_user

        post = PostCreator.create!(posting_user, default_opts)

        url = "https://#{Discourse.current_hostname}/t/slug/#{post.topic_id}"

        response = I18n.t("chatbot.prompt.function.escalate_to_staff.answer_summary", url: url)
      rescue
        I18n.t("chatbot.prompt.function.escalate_to_staff.error", parameter: args[parameters[0][:name]])
      end
    end

    def generate_transcript(messages, acting_user)
      messages = Array.wrap(messages)
      Chat::TranscriptService
        .new(messages.first.chat_channel, acting_user, messages_or_ids: messages.map(&:id))
        .generate_markdown
        .chomp
    end
  end
end

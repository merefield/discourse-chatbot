# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class # frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class EscalateToStaffFunction < Function

    def name
      'escalate_to_staff'
    end

    def description
      I18n.t("chatbot.prompt.function.escalate_to_staff.description")
    end

            # { name: "input", type: String, description: I18n.t("chatbot.prompt.function.escalate_to_staff.parameters.input") } ,
    def parameters
      []
    end

    def required
      []
    end

    def process(args, opts)
      begin
        super(args)

        return I18n.t("chatbot.prompt.function.escalate_to_staff.wrong_type_error" if opts[:type] != ::DiscourseChatbot::MESSAGE

        channel_id = opts[:topic_or_channel_id]

        channel = ::Chat::Channel.find(channel_id)

        # support_group = SiteSetting

        target_usernames = [current_user.username, bot_user.username].join(",")

        # Group.find()

        target_group_names = []

        SiteSetting.chatbot_escalate_to_staff_groups.each do |g|
          target_group_names << Group.where(group_id: g).name
        end

        default_opts = {
          # post_alert_options: { skip_send_email: true },
          raw: I18n.t("chatbot.prompt.function.escalate_to_staff.announcement"),
          skip_validations: true,
          title: I18n.t("chatbot.prompt.function.escalate_to_staff.title"),
          archetype: Archetype.private_message,
          target_usernames: target_usernames,
          target_groups: target_group_names
        }

        new_pm_post = PostCreator.create!(bot_user, default_opts)

        message_or_post_id = opts[:message_or_post_id]

        current_message = ::Chat::Message.find(message_or_post_id)

        message_collection = []
  
        message_collection << current_message
  
        collect_amount = SiteSetting.chatbot_escalate_to_staff_max_history
  
        while message_collection.length < collect_amount do
          # if current_message.in_reply_to_id
          #   current_message = ::Chat::Message.find(current_message.in_reply_to_id)
          # else
          prior_message = ::Chat::Message.where(chat_channel_id: current_message.chat_channel_id, deleted_at: nil).where('chat_messages.id < ?', current_message.id).last
          if prior_message.nil?
            break
          else
            current_message = prior_message
          end
          message_collection << current_message
        end
  
        content = copy_messages_to_clipboard(message_collection)

        default_opts = {
          topic_id: new_pm_post.topic_id,
          post_alert_options: { skip_send_email: true },
          raw: I18n.t("chatbot.prompt.function.escalate_to_staff.announcement", content),
          skip_validations: true,
          title: I18n.t("chatbot.prompt.function.escalate_to_staff.pm_prefix"),
          archetype: Archetype.private_message,
        }

        post = PostCreator.create!(bot_user, default_opts)

        response = I18n.t("chatbot.prompt.function.escalate_to_staff.answer_summary", post.topic.id)
      rescue
        I18n.t("chatbot.prompt.function.escalate_to_staff.error", parameter: args[parameters[0][:name]])
      end
    end

    def copy_messages_to_clipboard(messages)
      messages = Array.wrap(messages)
      messages.each { |message| channel_page.messages.select(message) }
      channel_page.selection_management.copy
      expect(PageObjects::Components::Toasts.new).to have_success(
        I18n.t("js.chat.quote.copy_success"),
      )
      clip_text = cdp.read_clipboard
      expect(clip_text.chomp).to eq(generate_transcript(messages, current_user))
      clip_text
    end

    # def self.collect_past_interactions(message_or_post_id)
    #   current_message = ::Chat::Message.find(message_or_post_id)

    #   message_collection = []

    #   message_collection << current_message

    #   collect_amount = SiteSetting.chatbot_max_look_behind

    #   while message_collection.length < collect_amount do

    #     if current_message.in_reply_to_id
    #       current_message = ::Chat::Message.find(current_message.in_reply_to_id)
    #     else
    #       prior_message = ::Chat::Message.where(chat_channel_id: current_message.chat_channel_id, deleted_at: nil).where('chat_messages.id < ?', current_message.id).last
    #       if prior_message.nil?
    #         break
    #       else
    #         current_message = prior_message
    #       end
    #     end

    #     message_collection << current_message
    #   end
    # end
end

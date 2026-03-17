# frozen_string_literal: true

require_relative "../function"

module DiscourseChatbot
  class EscalateToStaffFunction < Function
    def name
      "escalate_to_staff"
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

        if opts[:type] != ::DiscourseChatbot::MESSAGE
          return(I18n.t("chatbot.prompt.function.escalate_to_staff.wrong_type_error"))
        end

        current_user = User.find(opts[:user_id])
        current_escalation_topic_id =
          ::DiscourseChatbot.latest_chatbot_escalation_topic_id(current_user.id)

        if current_escalation_topic_id.present? &&
             !::DiscourseChatbot.chatbot_escalation_cooldown_elapsed?(current_user.id)
          current_escalation_url =
            "https://#{Discourse.current_hostname}/t/slug/#{current_escalation_topic_id}"
          return(
            {
              answer: {
                result:
                  I18n.t(
                    "chatbot.prompt.function.escalate_to_staff.existing_escalation_topic",
                    url: current_escalation_url,
                  ),
                topic_ids_found: [current_escalation_topic_id],
                post_ids_found: [],
                non_post_urls_found: [],
              },
              token_usage: 0,
            }
          )
        end

        channel_id = opts[:topic_or_channel_id]
        channel = ::Chat::Channel.find(channel_id)

        bot_user = User.find(opts[:bot_user_id])
        target_usernames = current_user.username

        target_group_names = []

        Array(SiteSetting.chatbot_escalate_to_staff_groups).each do |g|
          target_group_names << Group.find(g.to_i).name unless g.to_i == 0
        end

        if !target_group_names.empty?
          target_group_names = target_group_names.join(",")

          message_or_post_id = opts[:reply_to_message_or_post_id]

          message_collection = get_messages(message_or_post_id)

          content = generate_transcript(message_collection, bot_user)

          base_title = I18n.t("chatbot.prompt.function.escalate_to_staff.title")
          full_title = base_title

          if SiteSetting.chatbot_private_message_auto_title
            begin
              generated_title = generate_escalation_title(opts)
              full_title = "#{base_title}: #{generated_title}" if generated_title.present?
            rescue => e
              Rails.logger.error(
                "Chatbot: Error occurred while generating escalation title for user #{current_user.username}: #{e.message}",
              )
            end
          end

          default_opts = {
            post_alert_options: {
              skip_send_email: true,
            },
            raw: I18n.t("chatbot.prompt.function.escalate_to_staff.announcement", content: content),
            skip_validations: true,
            title: full_title,
            archetype: Archetype.private_message,
            target_usernames: target_usernames,
            target_group_names: target_group_names,
          }

          post = PostCreator.create!(current_user, default_opts)

          url = "https://#{Discourse.current_hostname}/t/slug/#{post.topic_id}"

          escalation_date =
            UserCustomField
              .where(
                user_id: current_user.id,
                name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD,
              )
              .order(id: :desc)
              .first_or_initialize
          escalation_date.value = Time.now.utc.to_s
          escalation_date.save!

          escalation_topic_id =
            UserCustomField
              .where(
                user_id: current_user.id,
                name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_TOPIC_ID_CUSTOM_FIELD,
              )
              .order(id: :desc)
              .first_or_initialize
          escalation_topic_id.value = post.topic_id.to_s
          escalation_topic_id.save!

          response = I18n.t("chatbot.prompt.function.escalate_to_staff.answer_summary", url: url)
        else
          response = I18n.t("chatbot.prompt.function.escalate_to_staff.no_escalation_groups")
        end
        {
          answer: {
            result: response,
            topic_ids_found: [post.topic_id],
            post_ids_found: [],
            non_post_urls_found: [],
          },
          token_usage: 0,
        }
      rescue => e
        Rails.logger.error(
          "Chatbot: Error occurred while attempting to escalate for user #{current_user.username}: #{e.message}",
        )
        {
          answer: {
            result:
              I18n.t(
                "chatbot.prompt.function.escalate_to_staff.error",
                parameter: args[parameters[0][:name]],
              ),
            topic_ids_found: [post.topic_id],
            post_ids_found: [],
            non_post_urls_found: [],
          },
          token_usage: 0,
        }
      end
    end

    def generate_transcript(messages, acting_user)
      messages = Array.wrap(messages)
      Chat::TranscriptService
        .new(messages.first.chat_channel, acting_user, messages_or_ids: messages.map(&:id))
        .generate_markdown
        .chomp
    end

    def get_messages(message_or_post_id)
      current_message = ::Chat::Message.find(message_or_post_id)

      message_collection = []

      message_collection << current_message

      collect_amount = SiteSetting.chatbot_escalate_to_staff_max_history

      while message_collection.length < collect_amount
        prior_message =
          ::Chat::Message
            .where(chat_channel_id: current_message.chat_channel_id, deleted_at: nil)
            .where("chat_messages.id < ?", current_message.id)
            .last
        if prior_message.nil?
          break
        else
          current_message = prior_message
        end
        message_collection << current_message
      end
      message_collection
    end

    def generate_escalation_title(opts)
      prior_messages = ::DiscourseChatbot::MessagePromptUtils.create_prompt(opts)

      bot = ::DiscourseChatbot::OpenAiBotBasic.new(opts)
      messages =
        prior_messages << {
          role: "user",
          content: I18n.t("chatbot.prompt.private_message.title_creation"),
        }

      if bot.reasoning_model?
        res = bot.client.responses.create(parameters: bot.responses_parameters(messages))
        bot.extract_responses_text(res)&.strip
      else
        res = bot.client.chat(parameters: { model: bot.model_name, messages: messages })

        return nil if res["error"].present?

        res.dig("choices", 0, "message", "content")&.strip
      end
    end
  end
end

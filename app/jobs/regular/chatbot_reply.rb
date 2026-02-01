# frozen_string_literal: true

# Job is triggered to respond to Message or Post appropriately, checking user's quota.
class ::Jobs::ChatbotReply < Jobs::Base
  sidekiq_options retry: 5, dead: false

  sidekiq_retries_exhausted do |msg, ex|
    reply_and_thoughts = { reply: I18n.t("chatbot.errors.retries"), inner_thoughts: nil }
    opts = msg["args"].first.transform_keys(&:to_sym)
    opts.merge!(reply_and_thoughts)
    type = opts[:type]
    if type == ::DiscourseChatbot::POST
      reply_creator = ::DiscourseChatbot::PostReplyCreator.new(opts)
    else
      reply_creator = ::DiscourseChatbot::MessageReplyCreator.new(opts)
    end
    reply_creator.create
  end

  def execute(opts)
    type = opts[:type]
    bot_user_id = opts[:bot_user_id]
    reply_to_message_or_post_id = opts[:reply_to_message_or_post_id]
    over_quota = opts[:over_quota]

    bot_user = ::User.find_by(id: bot_user_id)
    if type == ::DiscourseChatbot::POST
      post = ::Post.find_by(id: reply_to_message_or_post_id)
    else
      message = ::Chat::Message.find_by(id: reply_to_message_or_post_id)
    end

    create_bot_reply = false

    reply_and_thoughts = { reply: "", inner_thoughts: nil }

    return unless bot_user

    permitted_categories = SiteSetting.chatbot_permitted_categories.split("|")

    if over_quota
      reply_and_thoughts[:reply] = I18n.t("chatbot.errors.overquota")
    elsif type == ::DiscourseChatbot::POST && post
      is_private_msg = post.topic.private_message?
      opts.merge!(is_private_msg: is_private_msg)

      if is_private_msg && !post.topic.topic_allowed_users.exists?(user_id: bot_user_id)
        post.topic.topic_allowed_users.create!(user_id: bot_user_id)
      end

      begin
        presence = PresenceChannel.new("/discourse-presence/reply/#{post.topic.id}")
        presence.present(user_id: bot_user_id, client_id: "12345")
      rescue StandardError
        # ignore issues with permissions related to communicating presence
      end

      if (is_private_msg && !SiteSetting.chatbot_permitted_in_private_messages)
        reply_and_thoughts[:reply] = I18n.t("chatbot.errors.forbiddeninprivatemessages")
      elsif is_private_msg && SiteSetting.chatbot_permitted_in_private_messages ||
            !is_private_msg && SiteSetting.chatbot_permitted_all_categories ||
            (permitted_categories.include? post.topic.category_id.to_s)
        create_bot_reply = true
      else
        if permitted_categories.size > 0
          reply_and_thoughts[:reply] = I18n.t("chatbot.errors.forbiddenoutsidethesecategories")
          permitted_categories.each_with_index do |permitted_category, index|
            if index == permitted_categories.size - 1
              reply_and_thoughts[:reply] += "##{Category.find_by(id: permitted_category).slug}"
            else
              reply_and_thoughts[:reply] += "##{Category.find_by(id: permitted_category).slug}, "
            end
          end
        else
          reply_and_thoughts[:reply] = I18n.t("chatbot.errors.forbiddenanycategory")
        end
      end
    elsif type == ::DiscourseChatbot::MESSAGE && message
      chat_channel_id = message.chat_channel_id
      chat_channel = ::Chat::Channel.find(chat_channel_id)

      is_direct_msg = chat_channel.chatable_type == "DirectMessage"

      chat_category_id = nil

      chat_category_id = chat_channel.chatable_id if chat_channel.chatable_type == "Category"

      #opts.merge!(is_direct_msg: is_direct_msg)

      if (is_direct_msg && !SiteSetting.chatbot_permitted_in_chat)
        reply_and_thoughts[:reply] = I18n.t("chatbot.errors.forbiddeninchat")
      elsif SiteSetting.chatbot_permitted_in_chat &&
            (
              is_direct_msg || (!is_direct_msg && SiteSetting.chatbot_permitted_all_categories) ||
                (chat_category_id && (permitted_categories.include? chat_category_id.to_s))
            )
        create_bot_reply = true
      else
        if chat_channel.chatable_type == "Category"
          if permitted_categories.size > 0
            reply_and_thoughts[:reply] = I18n.t("chatbot.errors.forbiddenoutsidethesecategories")
            permitted_categories.each_with_index do |permitted_category, index|
              if index == permitted_categories.size - 1
                reply_and_thoughts[:reply] += "##{Category.find_by(id: permitted_category).slug}"
              else
                reply_and_thoughts[:reply] += "##{Category.find_by(id: permitted_category).slug}, "
              end
            end
          else
            reply_and_thoughts[:reply] = I18n.t("chatbot.errors.forbiddenanycategory")
          end
        end
      end
      begin
        presence = PresenceChannel.new("/chat-reply/#{message.chat_channel_id}")
        presence.present(user_id: bot_user_id, client_id: "12345")
      rescue StandardError
        # ignore issues with permissions related to communicating presence
      end
    end

    if create_bot_reply
      ::DiscourseChatbot.progress_debug_message("4. Retrieving new reply message...")
      begin
        case opts[:trust_level]
        when ::DiscourseChatbot::TRUST_LEVELS[0], ::DiscourseChatbot::TRUST_LEVELS[1],
             ::DiscourseChatbot::TRUST_LEVELS[2]
          if SiteSetting.send("chatbot_bot_type_" + opts[:trust_level] + "_trust") == "RAG"
            ::DiscourseChatbot.progress_debug_message("4a. Using RAG bot...")
            opts.merge!(chatbot_bot_type: "RAG")
            bot = ::DiscourseChatbot::OpenAiBotRag.new(opts)
          else
            ::DiscourseChatbot.progress_debug_message("4a. Using basic bot...")
            opts.merge!(chatbot_bot_type: "basic")
            bot = ::DiscourseChatbot::OpenAiBotBasic.new(opts)
          end
        else
          ::DiscourseChatbot.progress_debug_message("4a. Using basic bot...")
          opts.merge!(chatbot_bot_type: "basic")
          bot = ::DiscourseChatbot::OpenAiBotBasic.new(opts)
        end
        reply_and_thoughts = bot.ask(opts)
      rescue => e
        Rails.logger.error("Chatbot: There was a problem, but will retry til limit: #{e}")
        fail e
      end
    end
    opts.merge!(reply_and_thoughts)
    if type == ::DiscourseChatbot::POST
      reply_creator = ::DiscourseChatbot::PostReplyCreator.new(opts)
    else
      reply_creator = ::DiscourseChatbot::MessageReplyCreator.new(opts)
    end
    reply_creator.create
  end
end

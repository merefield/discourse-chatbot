# frozen_string_literal: true

# Job is triggered to respond to Message or Post appropriately, checking user's quota.
class ::Jobs::ChatbotReplyJob < Jobs::Base
  sidekiq_options retry: 5, dead: false

  sidekiq_retries_exhausted do |msg, ex|
    message_body = I18n.t('chatbot.errors.retries')
    opts = msg['args'].first.transform_keys(&:to_sym)
    opts.merge!(message_body: message_body)
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

    return unless bot_user

    if over_quota
      message_body = I18n.t('chatbot.errors.overquota')
    elsif type == ::DiscourseChatbot::POST && post
      message_body = nil
      is_private_msg = post.topic.private_message?

      permitted_categories = SiteSetting.chatbot_permitted_categories.split('|')

      if (is_private_msg && !SiteSetting.chatbot_permitted_in_private_messages)
        message_body = I18n.t('chatbot.errors.forbiddeninprivatemessages')
      elsif is_private_msg && SiteSetting.chatbot_permitted_in_private_messages || !is_private_msg && SiteSetting.chatbot_permitted_all_categories || (permitted_categories.include? post.topic.category_id.to_s)
        create_bot_reply = true
      else
        if permitted_categories.size > 0
          message_body = I18n.t('chatbot.errors.forbiddenoutsidethesecategories')
          permitted_categories.each_with_index do |permitted_category, index|
            if index == permitted_categories.size - 1
              message_body += "##{Category.find_by(id: permitted_category).slug}"
            else
              message_body += "##{Category.find_by(id: permitted_category).slug}, "
            end
          end
        else
          message_body = I18n.t('chatbot.errors.forbiddenanycategory')
        end
      end
    elsif type == ::DiscourseChatbot::MESSAGE && message
      create_bot_reply = true
    end
    if create_bot_reply
      puts "4. Retrieving new reply message..."
      begin
        bot = ::DiscourseChatbot::OpenAIBot.new
        message_body = bot.ask(opts)
      rescue => e
        Rails.logger.error ("OpenAIBot: There was a problem, but will retry til limit: #{e}")
        fail e
      end
    end
    opts.merge!(message_body: message_body)
    if type == ::DiscourseChatbot::POST
      reply_creator = ::DiscourseChatbot::PostReplyCreator.new(opts)
    else
      reply_creator = ::DiscourseChatbot::MessageReplyCreator.new(opts)
    end
    reply_creator.create
  end
end

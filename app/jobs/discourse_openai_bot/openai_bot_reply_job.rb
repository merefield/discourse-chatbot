class ::Jobs::OpenAIBotPostReplyJob < Jobs::Base
  sidekiq_options retry: false

  POST = "post"
  MESSAGE = "message"

  def execute(opts)
    type = opts[:type]
    bot_user_id = opts[:bot_user_id]
    reply_to_message_or_post_id = opts[:reply_to_message_or_post_id]

    bot_user = ::User.find_by(id: bot_user_id)
    if type == POST
      post = ::Post.find_by(id: reply_to_message_or_post_id)
    else
      message = ::ChatMessage.find_by(id: reply_to_message_or_post_id)
    end

    create_bot_reply = false

    if bot_user 
      if type == POST && post
        message_body = nil
        is_private_msg = post.topic.private_message?

        permitted_categories = SiteSetting.openai_bot_permitted_categories.split('|')

        if (is_private_msg && !SiteSetting.openai_bot_permitted_in_private_messages)
          message_body = I18n.t('openai_bot.errors.forbiddeninprivatemessages')
        elsif is_private_msg && SiteSetting.openai_bot_permitted_in_private_messages || !is_private_msg && SiteSetting.openai_bot_permitted_all_categories || (permitted_categories.include? post.topic.category_id.to_s)
          create_bot_reply = true
          # puts "Creating a new reply message..."
          # begin
          #   bot = DiscourseOpenAIBot::OpenAIBot.new
          #   message_body = bot.ask(opts)
          # rescue => e
          #   message_body = I18n.t('openai_bot.errors.general')
          #   Rails.logger.error ("OpenAIBot: There was a problem: #{e}")
          # end
        else
          if permitted_categories.size > 0
            message_body = I18n.t('openai_bot.errors.forbiddenoutsidethesecategories')
            permitted_categories.each_with_index do |permitted_category, index|
              if index == permitted_categories.size - 1
                message_body += "##{Category.find_by(id:permitted_category).slug}"
              else
                message_body += "##{Category.find_by(id:permitted_category).slug}, "
              end
            end
          else
            message_body = I18n.t('openai_bot.errors.forbiddenanycategory') 
          end
        end
        # reply_creator = DiscourseOpenAIBot::ReplyCreator.new(user: bot_user, reply_to: post)
        # reply_creator.create(message_body)
      elsif type == MESSAGE && message
        create_bot_reply = true
      end
      if create_bot_reply
        puts "Creating a new reply message..."
        begin
          bot = DiscourseOpenAIBot::OpenAIBot.new
          message_body = bot.ask(opts)
        # rescue => e
        #   message_body = I18n.t('openai_bot.errors.general')
        #   Rails.logger.error ("OpenAIBot: There was a problem: #{e}")
        end
      end
      opts.merge!(message_body: message_body)
      if type == POST
        reply_creator = DiscourseOpenAIBot::PostReplyCreator.new(opts)
      else
        reply_creator = DiscourseOpenAIBot::MessageReplyCreator.new(opts)
      end
      reply_creator.create
    end
  end
end
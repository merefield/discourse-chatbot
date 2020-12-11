class ::Jobs::FrotzBotPostReplyJob < Jobs::Base

  def execute(opts)

    bot_user_id = opts[:bot_user_id]
    reply_to_post_id = opts[:reply_to_post_id]

    bot_user = ::User.find_by(id: bot_user_id)
    post = ::Post.find_by(id: reply_to_post_id)

    if bot_user && post
      message_body = nil
      is_private_msg = post.topic.private_message?

      permitted_categories = SiteSetting.frotz_permitted_categories.split('|')

      if (is_private_msg && !SiteSetting.frotz_permitted_in_private_messages)
        message_body = I18n.t('frotz.errors.forbiddeninprivatemessages')
      elsif is_private_msg && SiteSetting.frotz_permitted_in_private_messages || !is_private_msg && SiteSetting.frotz_permitted_all_categories || (permitted_categories.include? post.topic.category_id.to_s)
        puts "Creating a new reply message..."
        begin
          message_body = DiscourseFrotz::FrotzBot.ask(opts)
        rescue => e
          message_body = I18n.t('frotz.errors.general')
          Rails.logger.error ("FroztBot: There was a problem: #{e}")
        end
      else
        if permitted_categories.size > 0
          message_body = I18n.t('frotz.errors.forbiddenoutsidethesecategories')
          permitted_categories.each_with_index do |permitted_category, index|
            if index == permitted_categories.size - 1
              message_body += "##{Category.find_by(id:permitted_category).slug}"
            else
              message_body += "##{Category.find_by(id:permitted_category).slug}, "
            end
          end
        else
          message_body = I18n.t('frotz.errors.forbiddenanycategory') 
        end
      end
      reply_creator = DiscourseFrotz::ReplyCreator.new(user: bot_user, reply_to: post)
      reply_creator.create(message_body)
    end
  end
end
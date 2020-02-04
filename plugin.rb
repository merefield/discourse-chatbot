# name: discourse-frotz
# about: a plugin that adds a Frotz bot that can tell interactive stories
# version: 0.1
# authors: merefield
# credits: is a mashup of an existing chatbot for Discourse by p08, ambisoft & merefield
# and a php RESTful wrapper for Frotz by Tim Lefler https://github.com/tlef/restful-frotz
# and of course relies on the Frotz interpreter here: https://gitlab.com/DavidGriffith/frotz
# specifically the dumb interface

require_relative 'lib/bot'
require_relative 'lib/frotzbot'
require_relative 'lib/reply_creator'

enabled_site_setting :discourse_frotz_enabled

after_initialize do

  class ::Jobs::DiscourseFrotzPostReplyJob < Jobs::Base

    def execute(opts)

      bot_user_id = opts[:bot_user_id]
      reply_to_post_id = opts[:reply_to_post_id]

      bot_user = ::User.find_by(id: bot_user_id)
      post = ::Post.find_by(id: reply_to_post_id)

      if bot_user && post
        message_body = nil
        begin
          message_body = DiscourseFrotz::FrotzBot.ask(opts)
        rescue => e
          message_body = I18n.t('frotz.errors.general')
          Rails.logger.error ("FroztBot: There was a problem: #{e}")
        end
        reply_creator = DiscourseFrotz::ReplyCreator.new(user: bot_user, reply_to: post)
        reply_creator.create(message_body)
      end
    end
  end

  DiscourseEvent.on(:post_created) do |*params|
    post, opts, user = params

    bot_username = SiteSetting.frotz_bot_user
    bot_user = User.find_by(username: bot_username)

    if (user.id != bot_user.id) && post.reply_count = 0
      bot = DiscourseFrotz::Bot.new
      bot.on_post_created(post)
    end
  end

end

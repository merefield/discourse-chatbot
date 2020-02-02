# name: discourse-frotz
# about: a plugin that adds a Frotz bot that can tell interactive stories
# version: 0.1
# authors: merefield
# credits: is a mashup of an existing chatbot interface for Discourse by p & merefield
# and a php RESTful wrapper for Frotz by Tim Lefler https://github.com/tlef/restful-frotz
# and of course relies on the Frotz interpreter here: https://gitlab.com/DavidGriffith/frotz
# specifically the dumb interface

require_relative 'lib/bot'
require_relative 'lib/frotzbot'
require_relative 'lib/reply_creator'

after_initialize do

  class ::Jobs::DiscourseFrotzPostReplyJob < Jobs::Base

    def execute(opts)

      #puts "DiscourseFroztPostReplyJob running..."

      bot_user_id = opts[:bot_user_id]
      reply_to_post_id = opts[:reply_to_post_id]
      message_body = opts[:message_body]

      bot_user = ::User.find_by(id: bot_user_id)
      post = ::Post.find_by(id: reply_to_post_id)

      #puts "Bot user: #{bot_user}"
      #puts "Post: #{post}"

      if bot_user && post
        reply_creator = DiscourseFrotz::ReplyCreator.new(user: bot_user, reply_to: post)
        reply_creator.create(message_body)
      end
    end
  end

  class ::Jobs::DiscourseFrotzCallFrotzBotJob < Jobs::Base

    def execute(opts)

      bot_user_id = opts[:bot_user_id]
      reply_to_post_id = opts[:reply_to_post_id]

      bot_user = ::User.find_by(id: bot_user_id)
      post = ::Post.find_by(id: reply_to_post_id)

      if bot_user && post
        message_body = nil
        #begin
          message_body = DiscourseFrotz::FrotzBot.ask(opts)
        #rescue
          
        #   message_body = "Sorry, I'm not well right now. Lets talk some other time."
        #end
        reply_creator = DiscourseFrotz::ReplyCreator.new(user: bot_user, reply_to: post)
        reply_creator.create(message_body)
      end
    end
  end

  DiscourseEvent.on(:post_created) do |*params|
    post, opts, user = params
    bot = DiscourseFrotz::Bot.new
    bot.on_post_created(post)
  end

end

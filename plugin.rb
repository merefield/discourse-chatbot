# name: discourse-chatbot
# about: a plugin that allows you to have a conversation with a configurable chatbot in Discourse Chat, Topics and Private Messages
# version: 0.2
# authors: merefield
# url: https://github.com/merefield/discourse-chatbot

gem "httparty", '0.21.0' #, {require: false}
gem "ruby-openai", '3.3.0', {require: false} 

module ::DiscourseChatbot
  PLUGIN_NAME = "discourse-chatbot"
  POST = "post"
  MESSAGE = "message"
  CHATBOT_QUERIES_CUSTOM_FIELD = "chatbot_queries"
  DELAY_IN_SECONDS = 3
end

require_relative "lib/discourse_chatbot/engine"

enabled_site_setting :chatbot_enabled
register_asset 'stylesheets/common/chatbot_common.scss'
register_asset 'stylesheets/mobile/chatbot_mobile.scss', :mobile
register_svg_icon 'robot'

after_initialize do
  SeedFu.fixture_paths << Rails
  .root
  .join("plugins", "discourse-chatbot", "db", "fixtures")
  .to_s

  %w(
    ../lib/discourse_chatbot/event_evaluation.rb
    ../lib/discourse_chatbot/message/message_evaluation.rb
    ../lib/discourse_chatbot/post/post_evaluation.rb
    ../lib/discourse_chatbot/bot.rb
    ../lib/discourse_chatbot/bots/open_ai_bot.rb
    ../lib/discourse_chatbot/prompt_utils.rb
    ../lib/discourse_chatbot/post/post_prompt_utils.rb
    ../lib/discourse_chatbot/message/message_prompt_utils.rb
    ../lib/discourse_chatbot/reply_creator.rb
    ../lib/discourse_chatbot/post/post_reply_creator.rb
    ../lib/discourse_chatbot/message/message_reply_creator.rb
    ../app/jobs/discourse_chatbot/regular/chatbot_reply_job.rb
    ../app/jobs/discourse_chatbot/scheduled/chatbot_quota_reset_job.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  #TODO support conversation ids if API supports
  #register_topic_custom_field_type("conversation_id", :string)

  register_user_custom_field_type(::DiscourseChatbot::CHATBOT_QUERIES_CUSTOM_FIELD, :integer)

  DiscourseEvent.on(:post_created) do |*params|
    post, opts, user = params

    if SiteSetting.chatbot_enabled
      puts "1. trigger"
      bot_username = SiteSetting.chatbot_bot_user
      bot_user = User.find_by(username: bot_username)

      if (user.id != bot_user.id) && post.reply_count = 0
        event_evaluation = DiscourseChatbot::PostEvaluation.new
        event_evaluation.on_submission(post)
      end
    end
  end

  DiscourseEvent.on(:chat_message_created) do |*params|
    chat_message, chat_channel, user = params

    if SiteSetting.chatbot_enabled
      puts "1. trigger"
      bot_username = SiteSetting.chatbot_bot_user
      bot_user = User.find_by(username: bot_username)

      if (user.id != bot_user.id) #&& post.reply_count = 0
        event_evaluation = DiscourseChatbot::MessageEvaluation.new
        event_evaluation.on_submission(chat_message)
      end
    end
  end

end

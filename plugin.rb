# name: discourse-chatbot
# about: a plugin that allows you to have a conversation with a configurable chatbot in Discourse Chat, Topics and Private Messages
# version: 0.1
# authors: merefield

gem "httparty", '0.21.0' #, {require: false}
gem "ruby-openai", '3.3.0', {require: false} 

module ::DiscourseChatbot
  PLUGIN_NAME = "discourse-chatbot"
  POST = "post"
  MESSAGE = "message"
  DELAY_IN_SECONDS = 3
end

require_relative "lib/discourse_chatbot/engine"

enabled_site_setting :chatbot_enabled

after_initialize do
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
    ../app/jobs/discourse_chatbot/chatbot_reply_job.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  #register_topic_custom_field_type("conversation_id", :string)

  # add_to_class(:topic, :conversation_id) do
  #   if !self.custom_fields["conversation_id"].nil?
  #     self.custom_fields["conversation_id"]
  #   else
  #     nil
  #   end
  # end

  # add_to_class(:topic, "conversation_id=") do |value|
  #   custom_fields["conversation_id"] = value
  # end
  
  # on(:topic_created) do |topic, opts, user|
  #   if opts[:conversation_id] != nil
  #     topic.custom_fields['conversation_id'] = opts[:conversation_id]
  #     topic.save_custom_fields(true)
  #   end
  # end
  
  ##
  # type:        step
  # number:      4.2
  # title:       Preload the field
  # description: Discourse preloads custom fields on listable models (i.e.
  #              categories or topics) before serializing them. This is to
  #              avoid running a potentially large number of SQL queries 
  #              ("N+1 Queries") at the point of serialization, which would
  #              cause performance to be affected.
  # references:  lib/plugins/instance.rb,
  #              app/models/topic_list.rb,
  #              app/models/concerns/has_custom_fields.rb
  ##
 # add_preloaded_topic_list_custom_field(FIELD_NAME)

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

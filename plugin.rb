# frozen_string_literal: true
# name: discourse-chatbot
# about: a plugin that allows you to have a conversation with a configurable chatbot in Discourse Chat, Topics and Private Messages
# version: 0.43
# authors: merefield
# url: https://github.com/merefield/discourse-chatbot

gem 'multipart-post', '2.3.0', { require: false }
gem 'faraday-multipart', '1.0.4', { require: false }
gem "ruby-openai", '5.1.0', { require: false }
# google search
gem "google_search_results", '2.2.0'
# wikipedia
gem "wikipedia-client", '1.17.0'
# safe ruby for calculations and date functions
gem "childprocess", "4.1.0"
gem "safe_ruby", "1.0.4"

module ::DiscourseChatbot
  PLUGIN_NAME = "discourse-chatbot"
  POST = "post"
  MESSAGE = "message"
  CHATBOT_QUERIES_CUSTOM_FIELD = "chatbot_queries"
  POST_TYPES_REGULAR_ONLY = [1]
  POST_TYPES_INC_WHISPERS = [1, 4]
  EMBEDDING_MODEL = "text-embedding-ada-002".freeze
  EMBEDDING_CHAR_LIMIT = 13500

  def progress_debug_message(message)
    if SiteSetting.chatbot_enable_verbose_console_response_progress_logging
      puts message
    end
  end

  module_function :progress_debug_message
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
    ../app/models/embedding.rb
    ../lib/discourse_chatbot/post_embedding_process.rb
    ../app/jobs/regular/chatbot_post_embedding_job.rb
    ../lib/discourse_chatbot/message/message_evaluation.rb
    ../lib/discourse_chatbot/post/post_evaluation.rb
    ../lib/discourse_chatbot/bot.rb
    ../lib/discourse_chatbot/bots/open_ai_bot_base.rb
    ../lib/discourse_chatbot/bots/open_ai_bot.rb
    ../lib/discourse_chatbot/bots/open_ai_agent.rb
    ../lib/discourse_chatbot/function.rb
    ../lib/discourse_chatbot/functions/calculator_function.rb
    ../lib/discourse_chatbot/functions/news_function.rb
    ../lib/discourse_chatbot/functions/wikipedia_function.rb
    ../lib/discourse_chatbot/functions/google_search_function.rb
    ../lib/discourse_chatbot/functions/forum_search_function.rb
    ../lib/discourse_chatbot/functions/stock_data_function.rb
    ../lib/discourse_chatbot/functions/parser.rb
    ../lib/discourse_chatbot/prompt_utils.rb
    ../lib/discourse_chatbot/post/post_prompt_utils.rb
    ../lib/discourse_chatbot/message/message_prompt_utils.rb
    ../lib/discourse_chatbot/reply_creator.rb
    ../lib/discourse_chatbot/post/post_reply_creator.rb
    ../lib/discourse_chatbot/message/message_reply_creator.rb
    ../app/jobs/regular/chatbot_reply_job.rb
    ../app/jobs/scheduled/chatbot_quota_reset_job.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  register_user_custom_field_type(::DiscourseChatbot::CHATBOT_QUERIES_CUSTOM_FIELD, :integer)

  DiscourseEvent.on(:post_created) do |*params|
    post, opts, user = params

    if SiteSetting.chatbot_enabled
      if post.post_type == 1
        job_class = ::Jobs::ChatbotPostEmbeddingJob
        job_class.perform_async(post.as_json)
      end

      if (post.post_type == 1 || post.post_type == 4 && SiteSetting.chatbot_can_trigger_from_whisper)
        ::DiscourseChatbot.progress_debug_message("1. trigger")

        bot_username = SiteSetting.chatbot_bot_user
        bot_user = User.find_by(username: bot_username)

        if bot_user && (user.id != bot_user.id)
          event_evaluation = ::DiscourseChatbot::PostEvaluation.new
          event_evaluation.on_submission(post)
        end
      end
    end
  end

  DiscourseEvent.on(:post_edited) do |*params|
    post, opts = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbeddingJob
      job_class.perform_async(post.as_json)
    end
  end

  DiscourseEvent.on(:post_recovered) do |*params|
    post, opts = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbeddingJob
      job_class.perform_async(post.as_json)
    end
  end

  DiscourseEvent.on(:post_destroyed) do |*params|
    post, opts, user = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbeddingDeleteJob
      job_class.perform_async(post.as_json)
    end
  end

  DiscourseEvent.on(:chat_message_created) do |*params|
    chat_message, chat_channel, user = params

    if SiteSetting.chatbot_enabled
      ::DiscourseChatbot.progress_debug_message("1. trigger")

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = User.find_by(username: bot_username)

      if bot_user && (user.id != bot_user.id)
        event_evaluation = ::DiscourseChatbot::MessageEvaluation.new
        event_evaluation.on_submission(chat_message)
      end
    end
  end
end

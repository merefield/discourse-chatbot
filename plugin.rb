# frozen_string_literal: true
# name: discourse-chatbot
# about: a plugin that allows you to have a conversation with a configurable chatbot in Chat, Topics and Private Messages
# version: 1.5.20
# authors: merefield
# url: https://github.com/merefield/discourse-chatbot

gem "domain_name", "0.6.20240107", { require: false }
gem "http-cookie", "1.0.8", { require: false }
gem "event_stream_parser", "1.0.0", { require: false }
gem "ruby-openai", "8.1.0", { require: false }
# google search
gem "google_search_results", "2.2.0"
# wikipedia
gem "wikipedia-client", "1.17.0"
# safe ruby for calculations and date functions
gem "childprocess", "5.0.0"
# gem "safe_ruby", "1.0.4" TODO add this back in if gem returns to being maintained

module ::DiscourseChatbot
  PLUGIN_NAME = "discourse-chatbot"
  POST = "post"
  MESSAGE = "message"

  CHATBOT_QUERIES_CUSTOM_FIELD = "chatbot_queries"
  CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD =
    "chatbot_remanining_quota_queries"
  CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD = "chatbot_remaining_quota_tokens"
  CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD =
    "chatbot_queries_quota_reach_escalation_date"
  CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD = "chatbot_last_escalation_date"
  POST_TYPES_REGULAR_ONLY = [1]
  POST_TYPES_INC_WHISPERS = [1, 4]

  TRUST_LEVELS = %w[low medium high]
  HIGH_TRUST_LEVEL = 3
  MEDIUM_TRUST_LEVEL = 2
  LOW_TRUST_LEVEL = 1

  EMBEDDING_PROCESS_POSTS_CHUNK = 300

  TOPIC_URL_REGEX = %r{\/t/[^/]+/(\d+)(?!\d|\/)}
  POST_URL_REGEX = %r{\/t/[^/]+/(\d+)/(\d+)(?!\d|\/)}
  NON_POST_URL_REGEX = %r{\bhttps?:\/\/[^\s\/$.?#].[^\s)]*}

  REASONING_MODELS = %w[
    o1
    o1-mini
    o3
    o3-mini
    o4-mini
    gpt-5
    gpt-5-mini
    gpt-5-nano
    gpt-5.1
  ]

  def progress_debug_message(message)
    if SiteSetting.chatbot_enable_verbose_console_logging
      puts "Chatbot: #{message}"
    end
    if SiteSetting.chatbot_enable_verbose_rails_logging == "all"
      case SiteSetting.chatbot_verbose_rails_logging_destination_level
      when "warn"
        Rails.logger.warn("Chatbot: #{message}")
      else
        Rails.logger.info("Chatbot: #{message}")
      end
    end
  end

  module_function :progress_debug_message
end

require_relative "lib/discourse_chatbot/engine"

enabled_site_setting :chatbot_enabled
register_asset "stylesheets/common/chatbot_common.scss"
register_asset "stylesheets/mobile/chatbot_mobile.scss", :mobile
register_svg_icon "robot"

DiscoursePluginRegistry.serialized_current_user_fields << "chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile"

after_initialize do
  # Allow user to disable quickchat Composer popup on mobile PMs
  User.register_custom_field_type(
    "chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile",
    :boolean
  )
  register_editable_user_custom_field :chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile
  register_editable_user_custom_field :chatbot_additional_prompt

  Category.register_custom_field_type(
    "chatbot_auto_response_additional_prompt",
    :string
  )

  SeedFu.fixture_paths << Rails
    .root
    .join("plugins", "discourse-chatbot", "db", "fixtures")
    .to_s

  %w[
    ../lib/discourse_chatbot/event_evaluation.rb
    ../app/models/discourse_chatbot/post_embedding.rb
    ../app/models/discourse_chatbot/post_embeddings_bookmark.rb
    ../app/models/discourse_chatbot/topic_title_embedding.rb
    ../app/models/discourse_chatbot/topic_embeddings_bookmark.rb
    ../lib/discourse_chatbot/embedding_process.rb
    ../lib/discourse_chatbot/post/post_embedding_process.rb
    ../lib/discourse_chatbot/topic/topic_title_embedding_process.rb
    ../lib/discourse_chatbot/embedding_completionist_process.rb
    ../lib/discourse_chatbot/message/message_evaluation.rb
    ../lib/discourse_chatbot/post/post_evaluation.rb
    ../lib/discourse_chatbot/bot.rb
    ../lib/discourse_chatbot/bots/open_ai_bot_base.rb
    ../lib/discourse_chatbot/bots/open_ai_bot_basic.rb
    ../lib/discourse_chatbot/bots/open_ai_bot_rag.rb
    ../lib/discourse_chatbot/safe_ruby/lib/safe_ruby.rb
    ../lib/discourse_chatbot/function.rb
    ../lib/discourse_chatbot/functions/remaining_quota_function.rb
    ../lib/discourse_chatbot/functions/user_field_function.rb
    ../lib/discourse_chatbot/functions/calculator_function.rb
    ../lib/discourse_chatbot/functions/escalate_to_staff_function.rb
    ../lib/discourse_chatbot/functions/news_function.rb
    ../lib/discourse_chatbot/functions/web_crawler_function.rb
    ../lib/discourse_chatbot/functions/web_search_function.rb
    ../lib/discourse_chatbot/functions/wikipedia_function.rb
    ../lib/discourse_chatbot/functions/vision_function.rb
    ../lib/discourse_chatbot/functions/paint_function.rb
    ../lib/discourse_chatbot/functions/paint_edit_function.rb
    ../lib/discourse_chatbot/functions/forum_search_function.rb
    ../lib/discourse_chatbot/functions/forum_user_distance_from_location_function.rb
    ../lib/discourse_chatbot/functions/forum_user_search_from_location_function.rb
    ../lib/discourse_chatbot/functions/forum_user_search_from_user_location_function.rb
    ../lib/discourse_chatbot/functions/forum_user_search_from_topic_location_function.rb
    ../lib/discourse_chatbot/functions/forum_get_user_address_function.rb
    ../lib/discourse_chatbot/functions/forum_topic_search_from_location_function.rb
    ../lib/discourse_chatbot/functions/forum_topic_search_from_user_location_function.rb
    ../lib/discourse_chatbot/functions/forum_topic_search_from_topic_location_function.rb
    ../lib/discourse_chatbot/functions/get_distance_between_locations_function.rb
    ../lib/discourse_chatbot/functions/coords_from_location_description_search.rb
    ../lib/discourse_chatbot/functions/stock_data_function.rb
    ../lib/discourse_chatbot/functions/parser.rb
    ../lib/discourse_chatbot/prompt_utils.rb
    ../lib/discourse_chatbot/post/post_prompt_utils.rb
    ../lib/discourse_chatbot/message/message_prompt_utils.rb
    ../lib/discourse_chatbot/reply_creator.rb
    ../lib/discourse_chatbot/post/post_reply_creator.rb
    ../lib/discourse_chatbot/message/message_reply_creator.rb
    ../app/controllers/discourse_chatbot/chatbot_controller.rb
    ../app/jobs/regular/chatbot_reply.rb
    ../app/jobs/regular/chatbot_post_embedding.rb
    ../app/jobs/regular/chatbot_post_embedding_delete.rb
    ../app/jobs/regular/chatbot_topic_title_embedding.rb
    ../app/jobs/regular/chatbot_topic_title_embedding_delete.rb
    ../app/jobs/scheduled/chatbot_quota_reset.rb
    ../app/jobs/scheduled/chatbot_embeddings_set_completer.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_QUERIES_CUSTOM_FIELD,
    :integer
  )
  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
    :integer
  )
  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
    :integer
  )
  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD,
    :date
  )

  add_to_serializer(:current_user, :chatbot_access) do
    !::DiscourseChatbot::EventEvaluation.new.trust_level(object.id).blank?
  end

  #TODO this prevents a NotFound error in reads controller. This is a bit of a hack, we should really be finding the source of the issue and fixing it there
  module ChatUpdateUserLastReadExtension
    def fetch_active_membership(guardian:, channel:)
      bot_user = ::User.find_by(username: SiteSetting.chatbot_bot_user)
      bot_guardian = Guardian.new(bot_user)
      bot_membership =
        ::Chat::ChannelMembershipManager.new(channel).find_for_user(
          bot_guardian.user
        )
      if bot_membership.nil?
        membership =
          ::Chat::ChannelMembershipManager.new(channel).find_for_user(
            guardian.user,
            following: true
          )
      else
        membership =
          ::Chat::ChannelMembershipManager.new(channel).find_for_user(
            guardian.user
          )
      end
      membership
    end
  end

  class ::Chat::UpdateUserLastRead
    prepend ChatUpdateUserLastReadExtension
  end

  DiscourseEvent.on(:post_created) do |*params|
    post, opts, user = params

    if SiteSetting.chatbot_enabled
      if post.post_type == 1
        job_class = ::Jobs::ChatbotPostEmbedding
        job_class.perform_async({ id: post.id }.stringify_keys)
      end

      if (
           post.post_type == 1 ||
             post.post_type == 4 && SiteSetting.chatbot_can_trigger_from_whisper
         )
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

  DiscourseEvent.on(:topic_destroyed) do |*params|
    topic, opts, user = params

    if SiteSetting.chatbot_enabled
      job_class = ::Jobs::ChatbotTopicTitleEmbeddingDelete
      job_class.perform_async({ id: topic.id }.stringify_keys)
    end
  end

  DiscourseEvent.on(:topic_recovered) do |*params|
    topic, opts = params

    if SiteSetting.chatbot_enabled
      job_class = ::Jobs::ChatbotTopicTitleEmbedding
      job_class.perform_async({ id: topic.id }.stringify_keys)
    end
  end

  DiscourseEvent.on(:topic_created) do |*params|
    topic, opts = params

    if SiteSetting.chatbot_enabled
      job_class = ::Jobs::ChatbotTopicTitleEmbedding
      job_class.perform_async({ id: topic.id }.stringify_keys)
    end
  end

  DiscourseEvent.on(:post_edited) do |*params|
    post, topic_changed, opts = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbedding
      job_class.perform_async({ id: post.id }.stringify_keys)

      if post.is_first_post? && topic_changed
        job_class = ::Jobs::ChatbotTopicTitleEmbedding
        job_class.perform_async({ id: post.topic.id }.stringify_keys)
      end
    end
  end

  DiscourseEvent.on(:post_recovered) do |*params|
    post, opts = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbedding
      job_class.perform_async({ id: post.id }.stringify_keys)
    end
  end

  DiscourseEvent.on(:post_destroyed) do |*params|
    post, opts, user = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbeddingDelete
      job_class.perform_async({ id: post.id }.stringify_keys)
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
  Jobs.enqueue(:backfill_chatbot_quotas)
end

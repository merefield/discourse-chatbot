# frozen_string_literal: true
# name: discourse-chatbot
# about: a plugin that allows you to have a conversation with a configurable chatbot in Chat, Topics and Private Messages
# version: 2.4.2
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
gem "dentaku", "3.5.7", { require: false }

module ::DiscourseChatbot
  PLUGIN_NAME = "discourse-chatbot"
  POST = "post"
  MESSAGE = "message"

  CHATBOT_QUERIES_CUSTOM_FIELD = "chatbot_queries"
  CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD = "chatbot_remanining_quota_queries"
  CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD = "chatbot_remaining_quota_tokens"
  CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD =
    "chatbot_queries_quota_reach_escalation_date"
  CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD = "chatbot_last_escalation_date"
  CHATBOT_LAST_ESCALATION_TOPIC_ID_CUSTOM_FIELD = "chatbot_last_escalation_topic_id"
  POST_TYPES_REGULAR_ONLY = [1]
  POST_TYPES_INC_WHISPERS = [1, 4]
  INNER_THOUGHTS_POST_PREFIX = "[details='Inner Thoughts']\n```json\n"

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
    gpt-5.6
    gpt-5.6-sol
    gpt-5.6-terra
    gpt-5.6-luna
    gpt-5.5
    gpt-5.5-pro
    gpt-5.4
    gpt-5.4-mini
    gpt-5.4-nano
    gpt-5.4-pro
    gpt-5
    gpt-5-pro
    gpt-5-mini
    gpt-5-nano
    gpt-5.1
    gpt-5.2
    gpt-5.2-pro
  ]

  def latest_chatbot_custom_field_values(user_id, name)
    UserCustomField.where(user_id: user_id, name: name).order(id: :desc).pluck(:value)
  end

  def latest_chatbot_custom_field_value(user_id, name)
    latest_chatbot_custom_field_values(user_id, name).first
  end

  def latest_chatbot_escalation_topic_id(user_id)
    values =
      latest_chatbot_custom_field_values(user_id, CHATBOT_LAST_ESCALATION_TOPIC_ID_CUSTOM_FIELD)

    values.each do |value|
      next if value.blank?
      next unless value.to_s.match?(/\A\d+\z/)

      return value.to_i
    end

    nil
  end

  def latest_chatbot_escalation_at(user_id)
    values = latest_chatbot_custom_field_values(user_id, CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD)

    values.each do |value|
      next if value.blank?

      parsed_value = Time.zone.parse(value)
      return parsed_value if parsed_value
    rescue ArgumentError, TypeError
      next
    end

    nil
  end

  def chatbot_escalation_cooldown_elapsed?(user_id, now: Time.zone.now)
    last_escalation_at = latest_chatbot_escalation_at(user_id)
    return true if last_escalation_at.nil?

    now >= (last_escalation_at + SiteSetting.chatbot_escalate_to_staff_cool_down_period.days)
  end

  def embedding_model_name
    custom_name = SiteSetting.chatbot_open_ai_embeddings_model_custom_name.to_s.strip
    custom_name.presence || SiteSetting.chatbot_open_ai_embeddings_model
  end

  def progress_debug_message(message)
    puts "Chatbot: #{message}" if SiteSetting.chatbot_enable_verbose_console_logging
    if SiteSetting.chatbot_enable_verbose_rails_logging == "all"
      case SiteSetting.chatbot_verbose_rails_logging_destination_level
      when "warn"
        Rails.logger.warn("Chatbot: #{message}")
      else
        Rails.logger.info("Chatbot: #{message}")
      end
    end
  end

  module_function :latest_chatbot_custom_field_values
  module_function :latest_chatbot_custom_field_value
  module_function :latest_chatbot_escalation_topic_id
  module_function :latest_chatbot_escalation_at
  module_function :chatbot_escalation_cooldown_elapsed?
  module_function :embedding_model_name
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
    :boolean,
  )
  register_editable_user_custom_field :chatbot_user_prefs_disable_quickchat_pm_composer_popup_mobile
  register_editable_user_custom_field :chatbot_additional_prompt

  Category.register_custom_field_type("chatbot_auto_response_additional_prompt", :string)

  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-chatbot", "db", "fixtures").to_s

  register_user_custom_field_type(::DiscourseChatbot::CHATBOT_QUERIES_CUSTOM_FIELD, :integer)
  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
    :integer,
  )
  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
    :integer,
  )
  register_user_custom_field_type(
    ::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD,
    :date,
  )

  add_to_serializer(:current_user, :chatbot_access) do
    ::DiscourseChatbot::EventEvaluation.new.trust_level(object.id).present?
  end

  #TODO this prevents a NotFound error in reads controller. This is a bit of a hack, we should really be finding the source of the issue and fixing it there
  module ChatUpdateUserLastReadExtension
    def fetch_active_membership(guardian:, channel:)
      bot_user = ::User.find_by(username: SiteSetting.chatbot_bot_user)
      bot_guardian = Guardian.new(bot_user)
      bot_membership =
        ::Chat::ChannelMembershipManager.new(channel).find_for_user(bot_guardian.user)
      if bot_membership.nil?
        membership =
          ::Chat::ChannelMembershipManager.new(channel).find_for_user(
            guardian.user,
            following: true,
          )
      else
        membership = ::Chat::ChannelMembershipManager.new(channel).find_for_user(guardian.user)
      end
      membership
    end
  end

  class ::Chat::UpdateUserLastRead
    prepend ChatUpdateUserLastReadExtension
  end

  on(:post_created) do |*params|
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
          event_evaluation = ::DiscourseChatbot::Post::PostEvaluation.new
          event_evaluation.on_submission(post)
        end
      end
    end
  end

  on(:topic_destroyed) do |*params|
    topic, opts, user = params

    if SiteSetting.chatbot_enabled
      job_class = ::Jobs::ChatbotTopicTitleEmbeddingDelete
      job_class.perform_async({ id: topic.id }.stringify_keys)
    end
  end

  on(:topic_recovered) do |*params|
    topic, opts = params

    if SiteSetting.chatbot_enabled
      job_class = ::Jobs::ChatbotTopicTitleEmbedding
      job_class.perform_async({ id: topic.id }.stringify_keys)
    end
  end

  on(:topic_created) do |*params|
    topic, opts = params

    if SiteSetting.chatbot_enabled
      job_class = ::Jobs::ChatbotTopicTitleEmbedding
      job_class.perform_async({ id: topic.id }.stringify_keys)
    end
  end

  on(:post_edited) do |*params|
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

  on(:post_recovered) do |*params|
    post, opts = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbedding
      job_class.perform_async({ id: post.id }.stringify_keys)
    end
  end

  on(:post_destroyed) do |*params|
    post, opts, user = params

    if SiteSetting.chatbot_enabled && post.post_type == 1
      job_class = ::Jobs::ChatbotPostEmbeddingDelete
      job_class.perform_async({ id: post.id }.stringify_keys)
    end
  end

  on(:chat_message_created) do |*params|
    chat_message, chat_channel, user = params

    if SiteSetting.chatbot_enabled
      ::DiscourseChatbot.progress_debug_message("1. trigger")

      bot_username = SiteSetting.chatbot_bot_user
      bot_user = User.find_by(username: bot_username)

      if bot_user && (user.id != bot_user.id)
        event_evaluation = ::DiscourseChatbot::Message::MessageEvaluation.new
        event_evaluation.on_submission(chat_message)
      end
    end
  end
  Jobs.enqueue(:backfill_chatbot_quotas)
end

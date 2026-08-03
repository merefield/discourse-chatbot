# frozen_string_literal: true

class MigrateChatbotToolSettings < ActiveRecord::Migration[8.0]
  LIST_DATA_TYPE = 8

  SETTING_RENAMES = {
    "chatbot_forum_search_function_max_results" => "chatbot_forum_search_tool_max_results",
    "chatbot_forum_search_function_similarity_threshold" =>
      "chatbot_forum_search_tool_similarity_threshold",
    "chatbot_forum_search_function_reranking_strategy" =>
      "chatbot_forum_search_tool_reranking_strategy",
    "chatbot_forum_search_function_reranking_groups" =>
      "chatbot_forum_search_tool_reranking_groups",
    "chatbot_forum_search_function_reranking_tags" => "chatbot_forum_search_tool_reranking_tags",
    "chatbot_forum_search_function_include_topic_titles" =>
      "chatbot_forum_search_tool_include_topic_titles",
    "chatbot_forum_search_function_results_content_type" =>
      "chatbot_forum_search_tool_results_content_type",
    "chatbot_forum_search_function_results_topic_max_posts_count_strategy" =>
      "chatbot_forum_search_tool_results_topic_max_posts_count_strategy",
    "chatbot_forum_search_function_results_topic_max_posts_count" =>
      "chatbot_forum_search_tool_results_topic_max_posts_count",
    "chatbot_forum_search_function_hybrid_search" => "chatbot_forum_search_tool_hybrid_search",
    "chatbot_function_response_char_limit" => "chatbot_tool_response_char_limit",
  }.freeze

  LEGACY_BOT_TYPE_DEFAULTS = { "low" => "basic", "medium" => "basic", "high" => "RAG" }.freeze

  LOW_AND_MEDIUM_RAG_TOOLS = %w[calculate remaining_bot_quota local_forum_search].freeze

  HIGH_RAG_TOOLS = %w[
    calculate
    wikipedia
    remaining_bot_quota
    local_forum_search
    news
    web_crawler
    web_search
    stock_data
  ].freeze

  def up
    return unless Migration::Helpers.existing_site?

    SETTING_RENAMES.each { |old_name, new_name| copy_setting(old_name, new_name) }
    LEGACY_BOT_TYPE_DEFAULTS.each_key { |trust_level| migrate_tools(trust_level) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def copy_setting(old_name, new_name)
    DB.exec(<<~SQL, old_name:, new_name:)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT :new_name, data_type, value, created_at, updated_at
      FROM site_settings
      WHERE name = :old_name
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def migrate_tools(trust_level)
    new_setting_name = "chatbot_tools_#{trust_level}_trust"
    return if setting_exists?(new_setting_name)

    tools = tools_for(trust_level)
    DB.exec(<<~SQL, name: new_setting_name, value: tools.join("|"), data_type: LIST_DATA_TYPE)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES (:name, :data_type, :value, NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def tools_for(trust_level)
    bot_type =
      setting_value("chatbot_bot_type_#{trust_level}_trust") ||
        LEGACY_BOT_TYPE_DEFAULTS.fetch(trust_level)
    return [] unless bot_type.casecmp?("RAG")
    return LOW_AND_MEDIUM_RAG_TOOLS if trust_level != "high"

    high_trust_tools
  end

  def high_trust_tools
    tools = HIGH_RAG_TOOLS.dup
    tools.delete("wikipedia") if setting_value("chatbot_wikipedia_function") == "f"
    tools << "user_information" if setting_enabled?("chatbot_user_fields_collection")

    tools << "vision" if %w[directly via_function].include?(setting_value("chatbot_support_vision"))

    if setting_enabled?("chatbot_support_picture_creation")
      tools.push("paint_picture", "paint_edit_picture")
    end

    tools << "escalate_to_staff" if setting_enabled?("chatbot_escalate_to_staff_function")

    tools
  end

  def setting_enabled?(name)
    setting_value(name) == "t"
  end

  def setting_exists?(name)
    DB.query_single("SELECT 1 FROM site_settings WHERE name = :name LIMIT 1", name:).any?
  end

  def setting_value(name)
    DB.query_single("SELECT value FROM site_settings WHERE name = :name LIMIT 1", name:).first
  end
end

# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe SiteSetting do
  before { enable_current_plugin }

  let(:settings) { SiteSetting.all_settings.index_by { |setting| setting[:setting] } }

  let(:dependency_metadata) do
    lambda do |name|
      settings
        .fetch(name)
        .slice(:depends_on, :depends_on_values, :depends_behavior, :dependent_setting_display)
        .compact
    end
  end

  it "serializes dependencies used to simplify the admin settings interface" do
    expect(dependency_metadata.call(:chatbot_open_ai_model_custom_name_high_trust)).to eq(
      depends_on: [:chatbot_open_ai_model_custom_high_trust],
      depends_behavior: :hidden,
      dependent_setting_display: "inline",
    )
    expect(dependency_metadata.call(:chatbot_open_ai_model_custom_api_version)).to eq(
      depends_on: [:chatbot_open_ai_model_custom_api_type],
      depends_on_values: {
        chatbot_open_ai_model_custom_api_type: ["azure"],
      },
      depends_behavior: :hidden,
      dependent_setting_display: "inline",
    )
    expect(dependency_metadata.call(:chatbot_permitted_categories)).to eq(
      depends_on: [:chatbot_permitted_all_categories],
      depends_on_values: {
        chatbot_permitted_all_categories: ["false"],
      },
      depends_behavior: :hidden,
      dependent_setting_display: "inline",
    )
    expect(dependency_metadata.call(:chatbot_quick_access_bot_kicks_off)).to eq(
      depends_on: [:chatbot_quick_access_talk_button],
      depends_on_values: {
        chatbot_quick_access_talk_button: ["chat", "personal message"],
      },
      depends_behavior: :hidden,
      dependent_setting_display: "inline",
    )
    expect(dependency_metadata.call(:chatbot_embeddings_categories)).to eq(
      depends_on: %i[chatbot_embeddings_enabled chatbot_embeddings_strategy],
      depends_on_values: {
        chatbot_embeddings_strategy: ["categories"],
      },
      depends_behavior: :hidden,
    )
    expect(dependency_metadata.call(:chatbot_forum_search_tool_reranking_groups)).to eq(
      depends_on: %i[chatbot_embeddings_enabled chatbot_forum_search_tool_reranking_strategy],
      depends_on_values: {
        chatbot_forum_search_tool_reranking_strategy: %w[group_promotion both],
      },
      depends_behavior: :hidden,
    )
    expect(
      dependency_metadata.call(:chatbot_forum_search_tool_results_topic_max_posts_count),
    ).to eq(
      depends_on: %i[
        chatbot_embeddings_enabled
        chatbot_forum_search_tool_results_content_type
        chatbot_forum_search_tool_results_topic_max_posts_count_strategy
      ],
      depends_on_values: {
        chatbot_forum_search_tool_results_content_type: ["topic"],
        chatbot_forum_search_tool_results_topic_max_posts_count_strategy: %w[
          just_enough
          stretch_if_required
          exact
        ],
      },
      depends_behavior: :hidden,
    )
    expect(dependency_metadata.call(:chatbot_verbose_rails_logging_destination_level)).to eq(
      depends_on: [:chatbot_enable_verbose_rails_logging],
      depends_on_values: {
        chatbot_enable_verbose_rails_logging: %w[api_calls_only all],
      },
      depends_behavior: :hidden,
      dependent_setting_display: "inline",
    )
  end

  it "uses more restrictive default tools for low-trust users" do
    default_tools =
      ::DiscourseChatbot::TRUST_LEVELS.index_with do |trust_level|
        SiteSetting.defaults["chatbot_tools_#{trust_level}_trust"].split("|")
      end

    expect(default_tools).to match(
      "low" => contain_exactly("calculate", "remaining_bot_quota"),
      "medium" => contain_exactly("calculate", "remaining_bot_quota", "local_forum_search"),
      "high" =>
        contain_exactly(
          "calculate",
          "wikipedia",
          "remaining_bot_quota",
          "local_forum_search",
          "news",
          "web_crawler",
          "web_search",
          "stock_data",
        ),
    )
  end
end

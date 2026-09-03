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
    %i[
      chatbot_open_ai_token
      chatbot_anthropic_token
      chatbot_google_gemini_token
      chatbot_x_ai_token
    ].each { |setting| expect(dependency_metadata.call(setting)).to eq(depends_on: []) }

    {
      open_ai: "chatbot_open_ai_model",
      anthropic: "chatbot_anthropic_model",
      google_gemini: "chatbot_google_gemini_model",
      x_ai: "chatbot_x_ai_model",
    }.each do |provider, setting_prefix|
      ::DiscourseChatbot::TRUST_LEVELS.each do |trust_level|
        expect(dependency_metadata.call("#{setting_prefix}_#{trust_level}_trust".to_sym)).to eq(
          depends_on: [:chatbot_llm_provider],
          depends_on_values: {
            chatbot_llm_provider: [provider.to_s],
          },
          depends_behavior: :hidden,
        )
      end
    end

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
    expect(dependency_metadata.call(:chatbot_api_supports_name_attribute)).to eq(
      depends_on: [:chatbot_llm_provider],
      depends_on_values: {
        chatbot_llm_provider: ["open_ai"],
      },
      depends_behavior: :hidden,
      dependent_setting_display: "inline",
    )
    expect(dependency_metadata.call(:chatbot_google_gemini_embeddings_model)).to eq(
      depends_on: %i[chatbot_embeddings_enabled chatbot_embeddings_provider],
      depends_on_values: {
        chatbot_embeddings_provider: ["google_gemini"],
      },
      depends_behavior: :hidden,
    )
    expect(dependency_metadata.call(:chatbot_x_ai_embeddings_model)).to eq(
      depends_on: %i[chatbot_embeddings_enabled chatbot_embeddings_provider],
      depends_on_values: {
        chatbot_embeddings_provider: ["x_ai"],
      },
      depends_behavior: :hidden,
    )
    expect(dependency_metadata.call(:chatbot_anthropic_vision_model)).to eq(
      depends_on: [:chatbot_vision_provider],
      depends_on_values: {
        chatbot_vision_provider: ["anthropic"],
      },
      depends_behavior: :hidden,
    )
    expect(dependency_metadata.call(:chatbot_x_ai_image_model)).to eq(
      depends_on: [:chatbot_image_provider],
      depends_on_values: {
        chatbot_image_provider: ["x_ai"],
      },
      depends_behavior: :hidden,
    )
    %i[
      chatbot_request_temperature
      chatbot_request_top_p
      chatbot_request_frequency_penalty
      chatbot_request_presence_penalty
    ].each do |setting|
      expect(dependency_metadata.call(setting)).to eq(
        depends_on: [:chatbot_llm_provider],
        depends_on_values: {
          chatbot_llm_provider: %w[open_ai x_ai],
        },
        depends_behavior: :hidden,
      )
    end
    expect(dependency_metadata.call(:chatbot_open_ai_model_reasoning_level)).to eq(
      depends_on: [:chatbot_llm_provider],
      depends_on_values: {
        chatbot_llm_provider: ["open_ai"],
      },
      depends_behavior: :hidden,
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

  it "selects the core tools by default at every trust level" do
    expected_tools = %w[calculate remaining_bot_quota local_forum_search]
    configured_settings =
      YAML.safe_load_file(
        File.expand_path("../../config/settings.yml", __dir__),
        aliases: true,
      ).fetch("plugins")

    ::DiscourseChatbot::TRUST_LEVELS.each do |trust_level|
      default_tools =
        configured_settings.fetch("chatbot_tools_#{trust_level}_trust").fetch("default").split("|")

      expect(default_tools).to include(*expected_tools)
    end
  end

  it "lists current models for every provider" do
    model_choices = lambda { |setting| settings.fetch(setting)[:valid_values].pluck(:value) }

    expect(model_choices.call(:chatbot_open_ai_model_high_trust)).to eq(
      %w[
        gpt-5.6
        gpt-5.6-sol
        gpt-5.6-terra
        gpt-5.6-luna
        gpt-5.5
        gpt-5.5-pro
        gpt-5.4
        gpt-5.4-pro
        gpt-5.4-mini
        gpt-5.4-nano
        gpt-5.2
        gpt-5.2-pro
        gpt-5.1
        gpt-5
        gpt-5-pro
        gpt-5-mini
        gpt-5-nano
        gpt-4.1
        gpt-4.1-mini
        gpt-4.1-nano
      ],
    )
    expect(model_choices.call(:chatbot_open_ai_embeddings_model)).to eq(
      %w[text-embedding-ada-002 text-embedding-3-small text-embedding-3-large],
    )
    expect(model_choices.call(:chatbot_support_picture_creation_model)).to eq(
      %w[gpt-image-2 gpt-image-1.5 gpt-image-1-mini],
    )
    expect(model_choices.call(:chatbot_anthropic_model_high_trust)).to eq(
      %w[claude-fable-5-1 claude-opus-5 claude-sonnet-5 claude-haiku-4-5],
    )
    expect(model_choices.call(:chatbot_google_gemini_model_high_trust)).to eq(
      %w[
        gemini-3.8-flash
        gemini-3.7-flash
        gemini-3.6-flash
        gemini-3.5-flash
        gemini-3.5-flash-lite
        gemini-3.1-pro-preview
        gemini-3.1-flash-lite
        gemini-3-flash-preview
        gemini-2.5-pro
        gemini-2.5-flash
        gemini-2.5-flash-lite
      ],
    )
    expect(model_choices.call(:chatbot_google_gemini_embeddings_model)).to eq(
      %w[gemini-embedding-2 gemini-embedding-001],
    )
    expect(model_choices.call(:chatbot_google_gemini_image_model)).to eq(
      %w[gemini-3.1-flash-image gemini-3.1-flash-lite-image gemini-3-pro-image],
    )
    expect(model_choices.call(:chatbot_x_ai_model_high_trust)).to eq(
      %w[grok-4.6 grok-4.5 grok-4.3 grok-build-0.1 grok-4.20-reasoning grok-4.20-non-reasoning],
    )
  end

  it "uses current provider model defaults" do
    defaults =
      %i[
        chatbot_google_gemini_model_high_trust
        chatbot_google_gemini_model_medium_trust
        chatbot_google_gemini_model_low_trust
        chatbot_google_gemini_vision_model
        chatbot_google_gemini_image_model
        chatbot_support_picture_creation_model
      ].to_h { |setting| [setting, settings.fetch(setting)[:default]] }

    expect(defaults).to eq(
      chatbot_google_gemini_model_high_trust: "gemini-3.8-flash",
      chatbot_google_gemini_model_medium_trust: "gemini-3.8-flash",
      chatbot_google_gemini_model_low_trust: "gemini-3.8-flash",
      chatbot_google_gemini_vision_model: "gemini-3.8-flash",
      chatbot_google_gemini_image_model: "gemini-3.1-flash-image",
      chatbot_support_picture_creation_model: "gpt-image-2",
    )
  end

  it "does not list dated model snapshots" do
    model_choices =
      settings
        .select { |name, setting| name.to_s.include?("model") && setting[:valid_values].present? }
        .values
        .flat_map { |setting| setting[:valid_values].pluck(:value) }

    expect(model_choices).not_to include(
      a_string_matching(
        /(?:-\d{8}\z|-\d{4}-\d{2}-\d{2}\z|-\d{2}-\d{4}\z|-\d{4}-(?:non-)?reasoning\z)/,
      ),
    )
  end

  it "provides translated provider names" do
    provider_setting = settings.fetch(:chatbot_llm_provider)

    expect(provider_setting[:valid_values]).to eq(
      [
        { name: "chatbot.llm_provider.open_ai", value: "open_ai" },
        { name: "chatbot.llm_provider.anthropic", value: "anthropic" },
        { name: "chatbot.llm_provider.google_gemini", value: "google_gemini" },
        { name: "chatbot.llm_provider.x_ai", value: "x_ai" },
      ],
    )
    expect(provider_setting[:translate_names]).to eq(true)

    expect(settings.fetch(:chatbot_embeddings_provider)[:valid_values].pluck(:value)).to eq(
      %w[open_ai google_gemini x_ai],
    )
    expect(settings.fetch(:chatbot_vision_provider)[:valid_values].pluck(:value)).to eq(
      %w[open_ai anthropic google_gemini x_ai],
    )
    expect(settings.fetch(:chatbot_image_provider)[:valid_values].pluck(:value)).to eq(
      %w[open_ai google_gemini x_ai],
    )
  end
end

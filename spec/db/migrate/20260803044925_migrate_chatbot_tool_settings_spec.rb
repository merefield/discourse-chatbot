# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-chatbot/db/migrate/20260803044925_migrate_chatbot_tool_settings",
        )

module DiscourseChatbot
  module MigrateChatbotToolSettingsSpecHelpers
    def migration_setting_names
      renamed_settings = described_class::SETTING_RENAMES.to_a.flatten
      bot_type_settings =
        described_class::LEGACY_BOT_TYPE_DEFAULTS.keys.map do |trust_level|
          "chatbot_bot_type_#{trust_level}_trust"
        end
      tool_settings =
        described_class::LEGACY_BOT_TYPE_DEFAULTS.keys.map do |trust_level|
          "chatbot_tools_#{trust_level}_trust"
        end
      feature_settings = %w[
        chatbot_escalate_to_staff_function
        chatbot_support_picture_creation
        chatbot_support_vision
        chatbot_user_fields_collection
        chatbot_wikipedia_function
      ]

      renamed_settings + bot_type_settings + tool_settings + feature_settings
    end

    def delete_migration_settings
      DB.exec(
        "DELETE FROM site_settings WHERE name IN (:setting_names)",
        setting_names: migration_setting_names,
      )
    end

    def store_setting(name, value, data_type: 1)
      DB.exec(<<~SQL, name:, value:, data_type:)
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES (:name, :data_type, :value, NOW(), NOW())
        ON CONFLICT (name) DO UPDATE SET data_type = :data_type, value = :value
      SQL
    end

    def setting(name)
      DB
        .query_single(
          "SELECT data_type, value FROM site_settings WHERE name = :name LIMIT 1",
          name:,
        )
        .then { |data_type, value| { data_type:, value: } if data_type }
    end

    def tool_setting(trust_level)
      setting("chatbot_tools_#{trust_level}_trust")
    end
  end
end

RSpec.describe MigrateChatbotToolSettings do
  subject(:migration) { described_class.new }

  include DiscourseChatbot::MigrateChatbotToolSettingsSpecHelpers

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before do
    Migration::Helpers.stubs(:existing_site?).returns(true)
    delete_migration_settings
  end

  after { delete_migration_settings }

  it "preserves the historical bot type defaults on existing sites" do
    migration.up

    aggregate_failures do
      expect(tool_setting("low")).to eq(data_type: 8, value: "")
      expect(tool_setting("medium")).to eq(data_type: 8, value: "")
      expect(tool_setting("high")).to eq(
        data_type: 8,
        value:
          "calculate|wikipedia|remaining_bot_quota|local_forum_search|news|web_crawler|web_search|stock_data",
      )
    end
  end

  it "gives explicitly configured low- and medium-trust RAG bots only the core tools" do
    store_setting("chatbot_bot_type_low_trust", "RAG", data_type: 7)
    store_setting("chatbot_bot_type_medium_trust", "RAG", data_type: 7)
    store_setting("chatbot_bot_type_high_trust", "basic", data_type: 7)
    store_setting("chatbot_wikipedia_function", "t", data_type: 5)
    store_setting("chatbot_user_fields_collection", "t", data_type: 5)
    store_setting("chatbot_support_vision", "via_function", data_type: 7)
    store_setting("chatbot_support_picture_creation", "t", data_type: 5)
    store_setting("chatbot_escalate_to_staff_function", "t", data_type: 5)

    migration.up

    aggregate_failures do
      expect(tool_setting("low")[:value]).to eq("calculate|remaining_bot_quota|local_forum_search")
      expect(tool_setting("medium")[:value]).to eq(
        "calculate|remaining_bot_quota|local_forum_search",
      )
      expect(tool_setting("high")[:value]).to eq("")
    end
  end

  it "maps the legacy high-trust RAG feature settings to tools" do
    store_setting("chatbot_wikipedia_function", "f", data_type: 5)
    store_setting("chatbot_user_fields_collection", "t", data_type: 5)
    store_setting("chatbot_support_vision", "directly", data_type: 7)
    store_setting("chatbot_support_picture_creation", "t", data_type: 5)
    store_setting("chatbot_escalate_to_staff_function", "t", data_type: 5)

    migration.up

    expect(tool_setting("high")[:value]).to eq(
      "calculate|remaining_bot_quota|local_forum_search|news|web_crawler|web_search|stock_data|user_information|vision|paint_picture|paint_edit_picture|escalate_to_staff",
    )

    DB.exec("DELETE FROM site_settings WHERE name = 'chatbot_tools_high_trust'")
    store_setting("chatbot_support_vision", "via_function", data_type: 7)
    migration.up

    expect(tool_setting("high")[:value].split("|")).to include("vision")
  end

  it "copies every renamed setting while retaining its legacy row" do
    described_class::SETTING_RENAMES.each_with_index do |(old_name, _new_name), index|
      store_setting(old_name, "legacy-value-#{index}", data_type: index + 1)
    end

    migration.up

    described_class::SETTING_RENAMES.each_with_index do |(old_name, new_name), index|
      expected_setting = { data_type: index + 1, value: "legacy-value-#{index}" }

      aggregate_failures "copying #{old_name}" do
        expect(setting(old_name)).to eq(expected_setting)
        expect(setting(new_name)).to eq(expected_setting)
      end
    end
  end

  it "preserves existing new settings and is safe to run more than once" do
    old_name, new_name = described_class::SETTING_RENAMES.first
    store_setting(old_name, "legacy-value", data_type: 1)
    store_setting(new_name, "new-value", data_type: 3)
    store_setting("chatbot_bot_type_low_trust", "RAG", data_type: 7)
    store_setting("chatbot_tools_low_trust", "calculate", data_type: 8)

    2.times { migration.up }

    aggregate_failures do
      expect(setting(new_name)).to eq(data_type: 3, value: "new-value")
      expect(tool_setting("low")).to eq(data_type: 8, value: "calculate")
      expect(
        DB.query_single(
          "SELECT COUNT(*) FROM site_settings WHERE name IN (:setting_names)",
          setting_names: [new_name, "chatbot_tools_low_trust"],
        ).first,
      ).to eq(2)
    end
  end

  it "uses an empty tool list for unrecognised legacy bot types" do
    store_setting("chatbot_bot_type_high_trust", "future_bot", data_type: 7)

    migration.up

    expect(tool_setting("high")).to eq(data_type: 8, value: "")
  end

  it "does not create settings on fresh installs" do
    Migration::Helpers.stubs(:existing_site?).returns(false)

    migration.up

    expect(
      DB.query_single(
        "SELECT COUNT(*) FROM site_settings WHERE name IN (:setting_names)",
        setting_names: migration_setting_names,
      ).first,
    ).to eq(0)
  end
end

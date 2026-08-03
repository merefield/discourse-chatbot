# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-chatbot/db/post_migrate/20260803045430_rename_chatbot_force_a_tool_setting_value",
        )

RSpec.describe RenameChatbotForceAToolSettingValue do
  subject(:migration) { described_class.new }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before do
    DB.exec("DELETE FROM site_settings WHERE name = :name", name: described_class::SETTING_NAME)
  end

  after do
    DB.exec("DELETE FROM site_settings WHERE name = :name", name: described_class::SETTING_NAME)
  end

  it "renames the legacy force-a-function value after deployment" do
    DB.exec(<<~SQL, name: described_class::SETTING_NAME, value: described_class::OLD_VALUE)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES (:name, 7, :value, NOW(), NOW())
    SQL

    migration.up

    expect(
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = :name",
        name: described_class::SETTING_NAME,
      ).first,
    ).to eq("force_a_tool")
  end

  it "does not change another selected value" do
    DB.exec(<<~SQL, name: described_class::SETTING_NAME)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES (:name, 7, 'force_local_forum_search', NOW(), NOW())
    SQL

    migration.up

    expect(
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = :name",
        name: described_class::SETTING_NAME,
      ).first,
    ).to eq("force_local_forum_search")
  end
end

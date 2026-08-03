# frozen_string_literal: true

class RenameChatbotForceAToolSettingValue < ActiveRecord::Migration[8.0]
  SETTING_NAME = "chatbot_tool_choice_first_iteration"
  OLD_VALUE = "force_a_function"
  NEW_VALUE = "force_a_tool"

  def up
    DB.exec(<<~SQL, name: SETTING_NAME, old_value: OLD_VALUE, new_value: NEW_VALUE)
      UPDATE site_settings
      SET value = :new_value, updated_at = NOW()
      WHERE name = :name AND value = :old_value
    SQL
  end

  def down
    DB.exec(<<~SQL, name: SETTING_NAME, old_value: OLD_VALUE, new_value: NEW_VALUE)
      UPDATE site_settings
      SET value = :old_value, updated_at = NOW()
      WHERE name = :name AND value = :new_value
    SQL
  end
end

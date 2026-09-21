# frozen_string_literal: true

require "enum_site_setting"

module DiscourseChatbot
  class BlockedQuestionsStrategySiteSetting < ::EnumSiteSetting
    def self.values
      choices = [{ name: "examples", value: "examples" }]
      choices.unshift({ name: "system_one", value: "system_one" }) if SystemOneClient.configured?
      choices
    end

    def self.valid_value?(value)
      # Keep the default and saved preference valid when credentials are removed.
      %w[system_one examples].include?(value)
    end
  end
end

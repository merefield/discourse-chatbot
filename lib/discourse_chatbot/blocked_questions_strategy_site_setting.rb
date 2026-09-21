# frozen_string_literal: true

require "enum_site_setting"

module DiscourseChatbot
  class BlockedQuestionsStrategySiteSetting < ::EnumSiteSetting
    def self.values
      strategies = ["examples"]
      strategies.unshift("system_one") if SystemOneClient.configured?
      strategies.map do |strategy|
        { name: "chatbot.blocked_questions_strategy.#{strategy}", value: strategy }
      end
    end

    def self.valid_value?(value)
      # Keep the default and saved preference valid when credentials are removed.
      %w[system_one examples].include?(value)
    end

    def self.translate_names?
      true
    end
  end
end

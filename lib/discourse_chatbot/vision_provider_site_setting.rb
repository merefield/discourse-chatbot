# frozen_string_literal: true

require "enum_site_setting"

module DiscourseChatbot
  class VisionProviderSiteSetting < ::EnumSiteSetting
    def self.values
      LlmProviderSiteSetting.values
    end

    def self.valid_value?(value)
      LlmProviderSiteSetting.valid_value?(value)
    end

    def self.translate_names?
      true
    end
  end
end

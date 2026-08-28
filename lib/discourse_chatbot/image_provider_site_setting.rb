# frozen_string_literal: true

require "enum_site_setting"

module DiscourseChatbot
  class ImageProviderSiteSetting < ::EnumSiteSetting
    def self.values
      @values ||=
        %w[open_ai google_gemini x_ai].map do |provider|
          { name: "chatbot.llm_provider.#{provider}", value: provider }
        end
    end

    def self.valid_value?(value)
      values.any? { |provider| provider[:value] == value }
    end

    def self.translate_names?
      true
    end
  end
end

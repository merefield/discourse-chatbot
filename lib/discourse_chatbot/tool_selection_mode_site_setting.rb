# frozen_string_literal: true

require "enum_site_setting"

module DiscourseChatbot
  class ToolSelectionModeSiteSetting < ::EnumSiteSetting
    def self.values
      modes = ["remove_definitions"]
      if SiteSetting.chatbot_llm_provider == "open_ai" &&
           SiteSetting.chatbot_open_ai_model_custom_api_type != "azure"
        modes << "restrict_calls"
      end
      modes.map { |mode| { name: "chatbot.tool_selection_mode.#{mode}", value: mode } }
    end

    def self.valid_value?(value)
      # Preserve the saved preference when the provider changes; requests apply a compatible mode.
      %w[remove_definitions restrict_calls].include?(value)
    end

    def self.translate_names?
      true
    end
  end
end

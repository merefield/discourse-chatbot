# frozen_string_literal: true
module ::DiscourseChatbot

  class PromptUtils

    def self.create_prompt(opts)
      raise "Overwrite me!"
    end

    def self.collect_past_interactions(message_or_post_id)
      raise "Overwrite me!"
    end
  end
end

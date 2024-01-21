# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot
  class Bot
    def get_response(prompt, opts)
      raise "Overwrite me!"
    end

    def ask(opts)
      content = opts[:type] == POST ? PostPromptUtils.create_prompt(opts) : MessagePromptUtils.create_prompt(opts)

      response = get_response(content, opts)
    end
  end
end

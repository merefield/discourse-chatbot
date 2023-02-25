# frozen_string_literal: true
require "openai"

module ::DiscourseOpenAIBot

  MESSAGE = "message"
  POST = "post"

  class Bot

    def initialize
      raise "Overwrite me!"
    end

    def get_response(prompt)
      raise "Overwrite me!"
    end

    def ask(opts)
      content = opts[:type] == POST ? PostPromptUtils.create_prompt(opts) : MessagePromptUtils.create_prompt(opts)

      response = get_response(content)
    end
  end
end

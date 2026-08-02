# frozen_string_literal: true

require "rails_helper"

module DiscourseChatbot
  module SpecHelpers
    def get_chatbot_output_fixture(path)
      JSON.parse(
        File.open("#{Rails.root}/plugins/discourse-chatbot/spec/fixtures/output/#{path}.json").read,
      ).with_indifferent_access
    end

    def get_chatbot_input_fixture(path)
      JSON.parse(
        File.open("#{Rails.root}/plugins/discourse-chatbot/spec/fixtures/input/#{path}.json").read,
        symbolize_names: true,
      )
    end

    def embedding_response(*vectors)
      {
        "data" =>
          vectors.each_with_index.map do |vector, index|
            { "index" => index, "embedding" => vector }
          end,
      }
    end
  end
end

RSpec.configure { |config| config.include DiscourseChatbot::SpecHelpers }

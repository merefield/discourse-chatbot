# frozen_string_literal: true

require 'rails_helper'

def get_chatbot_output_fixture(path)
  JSON.parse(
    File.open(
      "#{Rails.root}/plugins/discourse-chatbot/spec/fixtures/output/#{path}.json"
    ).read
  ).with_indifferent_access
end

def get_chatbot_input_fixture(path)
  JSON.parse(
    File.open(
      "#{Rails.root}/plugins/discourse-chatbot/spec/fixtures/input/#{path}.json"
    ).read, :symbolize_names => true
  )
end

# frozen_string_literal: true

require 'rails_helper'

def get_chatbot_fixture(path)
  JSON.parse(
    File.open(
      "#{Rails.root}/plugins/discourse-chatbot/spec/fixtures/#{path}.json"
    ).read
  ).with_indifferent_access
end

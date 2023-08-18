# frozen_string_literal: true

require 'webmock/rspec'
require 'rails_helper'

# frozen_string_literal: true

def get_chatbot_fixture(path)
  JSON.parse(
    File.open(
      "#{Rails.root}/plugins/discourse-chatbot/spec/fixtures/#{path}.json"
    ).read
  ).with_indifferent_access
end

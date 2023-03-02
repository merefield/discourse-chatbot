# frozen_string_literal: true
## The plugin store is not wiped between each test

require 'webmock/rspec'

RSpec.configure do |config|
  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

require 'rails_helper'

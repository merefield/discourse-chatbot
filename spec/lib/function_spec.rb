# frozen_string_literal: true
require_relative '../plugin_helper'

describe ::DiscourseChatbot::Function do
  let(:calc) { ::DiscourseChatbot::CalculatorFunction.new }
  let(:news) { ::DiscourseChatbot::NewsFunction.new }
  let(:search) { ::DiscourseChatbot::WikipediaFunction.new }

  it "validates legal arguments" do
    args = { 'input' => '3 + 4' }

    expect { calc.send(:validate_parameters, args) }.not_to raise_error
  end
  it "throws an exception for illegal arguments" do
    args = { 'input' => '3 + 4' }

    expect { search.send(:validate_parameters, args) }.to raise_error(ArgumentError)
  end
  it "throws an exception for arguments missing a required parameter" do
    args = { 'start_date' => '2023-08-15' } # missing 'query'

    expect { news.send(:validate_parameters, args) }.to raise_error(ArgumentError)
  end
  it "doesn't throw an exception for arguments including the required parameter" do
    args = { 'query' => 'Botswana' } # required 'query'

    expect { news.send(:validate_parameters, args) }.not_to raise_error
  end
end

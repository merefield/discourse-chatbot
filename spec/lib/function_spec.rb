# frozen_string_literal: true
require_relative '../plugin_helper'

describe ::DiscourseChatbot::Function do
  let(:calc) { ::DiscourseChatbot::CalculatorFunction.new }
  let(:news) { ::DiscourseChatbot::NewsFunction.new }
  let(:search) { ::DiscourseChatbot::WikipediaFunction.new }
  let(:paint) { ::DiscourseChatbot::PaintFunction.new }

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

  it "throws an exception for enum arguments outside the allowed values" do
    args = { "description" => "an illustration of a robot", "aspect_ratio" => "panorama" }

    expect { paint.send(:validate_parameters, args) }.to raise_error(ArgumentError)
  end

  it "accepts enum arguments within the allowed values" do
    args = { "description" => "an illustration of a robot", "aspect_ratio" => "portrait" }

    expect { paint.send(:validate_parameters, args) }.not_to raise_error
  end

  it "throws an exception for arguments with the wrong type" do
    args = { "description" => 123 }

    expect { paint.send(:validate_parameters, args) }.to raise_error(ArgumentError)
  end

  it "includes enum values in parsed function json" do
    func_json = ::DiscourseChatbot::Parser.func_to_json(paint)

    expect(func_json.dig("parameters", "properties", "aspect_ratio", "enum")).to eq(
      %w[square landscape portrait],
    )
  end
end

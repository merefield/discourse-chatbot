# frozen_string_literal: true
require_relative "../plugin_helper"

describe ::DiscourseChatbot::Tool do
  let(:calc) { ::DiscourseChatbot::Tools::Calculator.new }
  let(:news) { ::DiscourseChatbot::Tools::News.new }
  let(:search) { ::DiscourseChatbot::Tools::Wikipedia.new }
  let(:paint) { ::DiscourseChatbot::Tools::Paint.new }

  it "lists every built-in tool for trust-level settings" do
    expect(described_class.choices).to include(*described_class::BUILT_IN_TOOL_NAMES)
  end

  it "validates legal arguments" do
    args = { "input" => "3 + 4" }

    expect { calc.send(:validate_parameters, args) }.not_to raise_error
  end
  it "throws an exception for illegal arguments" do
    args = { "input" => "3 + 4" }

    expect { search.send(:validate_parameters, args) }.to raise_error(ArgumentError)
  end
  it "throws an exception for arguments missing a required parameter" do
    args = { "start_date" => "2023-08-15" } # missing 'query'

    expect { news.send(:validate_parameters, args) }.to raise_error(ArgumentError)
  end
  it "doesn't throw an exception for arguments including the required parameter" do
    args = { "query" => "Botswana" } # required 'query'

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

  it "includes enum values in the parsed tool schema" do
    tool_json = ::DiscourseChatbot::Tools::Parser.tool_to_json(paint)

    expect(tool_json.dig("parameters", "properties", "aspect_ratio", "enum")).to eq(
      %w[square landscape portrait],
    )
  end
end

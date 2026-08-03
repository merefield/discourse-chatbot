# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::Calculator do
  let(:calc) { ::DiscourseChatbot::Tools::Calculator.new }

  it "returns the calculation result" do
    args = { "input" => "3 + 4" }

    expect(calc.process(args)).to eq({ answer: 7, token_usage: 0 })
  end

  it "returns a translated error for unsupported expressions" do
    args = { "input" => "File.read('/etc/passwd')" }

    expect(calc.process(args)).to eq(
      {
        answer: I18n.t("chatbot.prompt.function.calculator.error", parameter: args["input"]),
        token_usage: 0,
      },
    )
  end
end

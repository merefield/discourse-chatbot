# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::Calculator do
  let(:calc) { ::DiscourseChatbot::Tools::Calculator.new }

  it "returns the calculation result for a common model-generated constant" do
    args = { "input" => "3 * Math::PI" }

    result = calc.process(args)

    expect(result[:answer]).to be_within(0.000_001).of(3 * Math::PI)
    expect(result[:token_usage]).to eq(0)
  end

  it "returns correction guidance and rejects an unchanged failed expression" do
    args = { "input" => "File.read('/etc/passwd')" }

    expect(calc.process(args)).to eq(
      {
        answer: I18n.t("chatbot.prompt.function.calculator.error", parameter: args["input"]),
        token_usage: 0,
      },
    )
    expect(calc.process(args)).to eq(
      {
        answer:
          I18n.t("chatbot.prompt.function.calculator.repeated_error", parameter: args["input"]),
        token_usage: 0,
      },
    )
  end

  it "validates malformed arguments before rejecting a repeated expression" do
    args = { "input" => "File.read('/etc/passwd')" }
    calc.process(args)

    expect(calc.process(args.merge("unexpected" => "value"))).to eq(
      {
        answer: I18n.t("chatbot.prompt.function.calculator.error", parameter: args["input"]),
        token_usage: 0,
      },
    )
  end
end

# frozen_string_literal: true

require_relative "../../plugin_helper"

describe DiscourseChatbot::Tools::FunctionPlot do
  let(:tool) { described_class.new }

  it "returns a renderable graph block for multiple curves at no external API quota cost" do
    result =
      tool.process(
        "expressions" => "sin(x)\ncos(x)",
        "title" => "Sine and cosine",
        "x_min" => -7,
        "x_max" => 7,
        "y_min" => -1.5,
        "y_max" => 1.5,
      )

    expect(result[:token_usage]).to eq(0)
    expect(result[:answer]).to start_with("```function-plot\n")
    expect(result[:answer]).to end_with("\n```")
    expect(JSON.parse(result[:answer].lines[1])).to eq(
      "functions" => %w[sin(x) cos(x)],
      "title" => "Sine and cosine",
      "x_domain" => [-7, 7],
      "y_domain" => [-1.5, 1.5],
    )
  end

  it "accepts supported mathematical functions, powers and constants without evaluating a domain" do
    %w[
      x^2-4
      -x^2
      2^-x
      1/x
      sqrt(x)
      log(x)
      log10(x)
      exp(x)
      abs(x)
      floor(x)
      ceil(x)
      asin(x)
      acos(x)
      atan(x)
      tan(x)
      pi*x
      e^x
      1e3*x
    ].each do |expression|
      result = tool.process("expressions" => expression)
      expect(result[:answer]).to start_with("```function-plot\n"), expression
    end
  end

  it "prepares 3D surfaces with two independent variables and z bounds" do
    result =
      tool.process(
        "dimensions" => 3,
        "expressions" => "sin(x)*cos(y)\nx^2-y^2",
        "z_min" => -2,
        "z_max" => 2,
      )
    graph = JSON.parse(result[:answer].lines[1])

    expect(graph).to include(
      "dimensions" => 3,
      "functions" => %w[sin(x)*cos(y) x^2-y^2],
      "z_domain" => [-2, 2],
    )
    expect(result[:token_usage]).to eq(0)
  end

  it "rejects unsafe, malformed and oversized graph requests with correction guidance" do
    invalid = [
      {},
      { "expressions" => "" },
      { "expressions" => "x\nx\nx\nx\nx" },
      { "expressions" => "x" * 257 },
      { "expressions" => "(" * 17 + "x" + ")" * 17 },
      { "expressions" => "window.alert(1)" },
      { "expressions" => "x;alert(1)" },
      { "expressions" => "constructor(x)" },
      { "expressions" => "x=1" },
      { "expressions" => "y=x^2" },
      { "expressions" => "sin(" },
      { "expressions" => "x", "x_min" => 0 },
      { "expressions" => "x", "x_min" => 10, "x_max" => 0 },
      { "expressions" => "x", "y_min" => -Float::INFINITY, "y_max" => 10 },
      { "expressions" => "x", "x_min" => -10, "x_max" => 1_000_001 },
      { "expressions" => "x", "title" => "a" * 121 },
      { "expressions" => "x", "unexpected" => "value" },
      { "expressions" => "y" },
      { "expressions" => "x", "dimensions" => 4 },
      { "expressions" => "x", "z_min" => -1, "z_max" => 1 },
      { "expressions" => "x", "dimensions" => 3, "z_min" => 1 },
      { "expressions" => "x\ny\nx+y", "dimensions" => 3 },
    ]
    invalid.each do |arguments|
      expect(tool.process(arguments)).to eq(
        answer: I18n.t("chatbot.prompt.function.function_plot.error"),
        token_usage: 0,
      ),
      arguments.inspect
    end
  end

  it "escapes graph contents during cooking and preserves the fallback definition" do
    result = tool.process("expressions" => "x^2", "title" => "<script>alert(1)</script>")
    cooked = Nokogiri::HTML5.fragment(PrettyText.cook(result[:answer]))

    expect(cooked.css("script")).to be_empty
    expect(cooked.at_css("pre code.lang-function-plot").text).to include(
      '"functions":["x^2"]',
      "<script>alert(1)</script>",
    )
  end
end

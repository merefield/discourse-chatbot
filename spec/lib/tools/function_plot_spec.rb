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
      cbrt(x)
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

  it "prepares each additional 2D family through the same compact tool" do
    cases = [
      ["implicit", "x^2+y^2-4", "functions", ["x^2+y^2-4"]],
      ["parametric", "cos(t); sin(t)", "functions", [%w[cos(t) sin(t)]]],
      ["polar", "2*cos(3*theta)", "functions", ["2*cos(3*theta)"]],
      ["points", "0,1\n2,3", "points", [[0, 1], [2, 3]]],
      ["polyline", "0,1\n2,3", "points", [[0, 1], [2, 3]]],
      ["vector", "3,2\n1,1,-2,1", "vectors", [[0, 0, 3, 2], [1, 1, -2, 1]]],
    ]
    cases.each do |type, expressions, key, expected|
      result = tool.process("plot_type" => type, "expressions" => expressions)
      graph = JSON.parse(result[:answer].lines[1])
      expect(graph).to include("plot_type" => type, key => expected)
      if %w[parametric polar].include?(type)
        expect(graph["parameter_range"]).to eq([0, 2 * Math::PI])
      end
      expect(result[:token_usage]).to eq(0)
    end
    expect(tool.parameters.map { |parameter| parameter[:name] }).to eq(
      %w[expressions title plot_type x_min x_max y_min y_max parameter_min parameter_max],
    )
  end

  it "uses parameter bounds for trajectories and ignores placeholders for ordinary functions" do
    args = {
      "expressions" => "exp(-0.15*x)*sin(3*x)\nexp(-0.15*x)\n-exp(-0.15*x)",
      "parameter_min" => 0,
      "parameter_max" => 0,
    }
    graph = JSON.parse(tool.process(args)[:answer].lines[1])
    expect(graph["functions"].length).to eq(3)
    expect(graph).not_to have_key("parameter_range")

    graph =
      JSON.parse(
        tool.process(
          "plot_type" => "polar",
          "expressions" => "theta",
          "parameter_min" => -2,
          "parameter_max" => 4,
        )[
          :answer
        ].lines[
          1
        ],
      )
    expect(graph["parameter_range"]).to eq([-2, 4])
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
      { "expressions" => "x", "plot_type" => "surface" },
      { "expressions" => "x", "plot_type" => "polar" },
      { "expressions" => "t", "plot_type" => "parametric" },
      { "expressions" => "t; t; t", "plot_type" => "parametric" },
      { "expressions" => "t; y", "plot_type" => "parametric" },
      { "expressions" => "x\ny\nx+y", "plot_type" => "implicit" },
      { "expressions" => "theta", "plot_type" => "polar", "parameter_min" => 0 },
      {
        "expressions" => "theta",
        "plot_type" => "polar",
        "parameter_min" => 0,
        "parameter_max" => 0,
      },
      { "expressions" => "0,NaN", "plot_type" => "points" },
      { "expressions" => "0,1e309", "plot_type" => "points" },
      { "expressions" => "0,1000001", "plot_type" => "points" },
      { "expressions" => "0,1,2", "plot_type" => "polyline" },
      { "expressions" => "0,1,2", "plot_type" => "vector" },
      { "expressions" => "0,", "plot_type" => "points" },
      { "expressions" => "0,2*x", "plot_type" => "points" },
      { "expressions" => "0,1\n" * 151, "plot_type" => "points" },
      { "expressions" => "0,1\n" * 17, "plot_type" => "vector" },
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

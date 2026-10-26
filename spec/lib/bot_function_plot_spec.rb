# frozen_string_literal: true

require_relative "../plugin_helper"
require "openai"

describe DiscourseChatbot::Bot do
  let(:client) { mock }
  let(:requests) { [] }

  before do
    SiteSetting.chatbot_tools_low_trust = "plot_function"
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    OpenAI::Client.stubs(:new).returns(client)
  end

  it "uses the graph tool and returns a maths explanation accompanied by the prepared block" do
    graph = DiscourseChatbot::FunctionPlot.markdown("expressions" => "x^2-4")
    answer = "The roots of $x^2-4=0$ are $x=\\pm2$.\n\n#{graph}"
    client
      .expects(:chat)
      .twice
      .with do |parameters:|
        requests << parameters.deep_dup
        true
      end
      .returns(
        {
          "choices" => [
            {
              "finish_reason" => "tool_calls",
              "message" => {
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_graph",
                    "type" => "function",
                    "function" => {
                      "name" => "plot_function",
                      "arguments" => '{"expressions":"x^2-4"}',
                    },
                  },
                ],
              },
            },
          ],
          "usage" => {
            "total_tokens" => 10,
          },
        },
        {
          "choices" => [{ "finish_reason" => "stop", "message" => { "content" => answer } }],
          "usage" => {
            "total_tokens" => 10,
          },
        },
      )

    result =
      described_class.new({}).get_response(
        [{ role: "user", content: "Explain the roots of x squared minus four" }],
        {},
      )

    expect(requests.first[:tools].map { |tool| tool[:function]["name"] }).to eq(["plot_function"])
    expect(requests.last[:messages].find { |message| message[:role] == "tool" }[:content]).to eq(
      graph,
    )
    expect(result[:reply]).to eq(answer)
    expect(result[:inner_thoughts].find { |entry| entry[:role] == "tool" }[:content]).to eq(graph)
  end

  it "exposes the graph tool only when rendering is enabled and the trust level permits it" do
    tool_sets = []
    client
      .expects(:chat)
      .times(3)
      .with do |parameters:|
        tool_sets << Array(parameters[:tools]).map { |tool| tool[:function]["name"] }
        true
      end
      .returns(
        "choices" => [{ "finish_reason" => "stop", "message" => { "content" => "Done." } }],
        "usage" => {
          "total_tokens" => 10,
        },
      )

    described_class.new({}).get_response([{ role: "user", content: "Plot x" }], {})
    SiteSetting.chatbot_function_plot_enabled = false
    described_class.new({}).get_response([{ role: "user", content: "Plot x" }], {})
    SiteSetting.chatbot_function_plot_enabled = true
    SiteSetting.chatbot_tools_low_trust = "calculate"
    described_class.new({}).get_response([{ role: "user", content: "Plot x" }], {})

    expect(tool_sets).to eq([["plot_function"], [], ["calculate"]])
  end
end

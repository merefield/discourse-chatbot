# frozen_string_literal: true
require_relative "../plugin_helper"
require_relative "../support/tool_selection_helpers"
require "openai"

describe DiscourseChatbot::Bot, "#get_response" do
  include DiscourseChatbot::ToolSelectionHelpers

  let(:client) { mock }
  let(:requests) { [] }
  let(:url) { SiteSetting.chatbot_system_one_url }
  let(:prompt) { [{ role: "user", content: "What is 2 + 2?" }] }
  let(:selection_response) do
    {
      model: "jev-1.13.0",
      answers: {
        tool_0: judgment("relevant"),
        tool_1: judgment("irrelevant"),
      },
      usage: {
        input_tokens: 100,
        output_tokens: 20,
      },
    }
  end
  let(:final_response) do
    {
      "choices" => [{ "finish_reason" => "stop", "message" => { "content" => "Four." } }],
      "usage" => {
        "total_tokens" => 10,
      },
    }
  end

  before do
    DiscourseChatbot::Tool.stubs(:descendants).returns([])
    SiteSetting.chatbot_system_one_tool_selection_enabled = true
    SiteSetting.chatbot_system_one_key = "test-key"
    SiteSetting.chatbot_tools_low_trust = "calculate|wikipedia"
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    OpenAI::Client.stubs(:new).returns(client)
  end

  it "filters schemas and adds diagnostics without putting them in model context" do
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_chat
    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:function]["name"] }).to eq(["calculate"])
    expect(result[:inner_thoughts].first).to include(
      type: "tool_selection",
      removed_tools: ["wikipedia"],
    )
    expect(JSON.generate(requests.first[:messages])).not_to include(
      "tool_selection",
      "removed_tools",
    )
    expect(result[:usage_statistics][:total_tokens]).to eq(10)
  end

  it "filters Responses API tools as well as Chat Completions tools" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    responses = mock
    client.stubs(:responses).returns(responses)
    stub_request(:post, url).to_return(body: selection_response.to_json)
    responses
      .expects(:create)
      .with do |parameters:|
        expect(parameters[:tools].map { |tool| tool[:name] }).to eq(["calculate"])
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "role" => "assistant",
              "content" => [{ "type" => "output_text", "text" => "Four." }],
            },
          ],
          "usage" => {
            "total_tokens" => 10,
          },
        },
      )

    expect(described_class.new({}).get_response(prompt, {})[:reply]).to eq("Four.")
  end

  it "does not evaluate or add diagnostics when the feature is disabled" do
    SiteSetting.chatbot_system_one_tool_selection_enabled = false
    capture_chat
    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:function]["name"] }).to eq(
      %w[calculate wikipedia],
    )
    expect(result[:inner_thoughts]).to eq([])
    expect(WebMock).not_to have_requested(:post, url)
  end

  it "keeps the eligible tools and explains fallback when System One is unavailable" do
    stub_request(:post, url).to_return(status: 503, body: "unavailable")
    capture_chat
    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:function]["name"] }).to eq(
      %w[calculate wikipedia],
    )
    expect(result[:inner_thoughts].first).to include(outcome: "fallback", removed_tools: [])
  end

  it "omits the tools parameter and adds date context when all tools are removed" do
    selection_response[:answers][:tool_0] = judgment("irrelevant")
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_chat
    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first).not_to have_key(:tools)
    expect(requests.first[:messages].map { |message| message[:content] }.join).to include(
      Date.current.iso8601,
    )
    expect(result[:inner_thoughts].first[:removed_tools]).to eq(%w[calculate wikipedia])
  end

  it "preserves a forced tool call when all tools were judged irrelevant" do
    SiteSetting.chatbot_tool_choice_first_iteration = "force_a_tool"
    selection_response[:answers][:tool_0] = judgment("irrelevant")
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_chat

    result = described_class.new({}).get_response(prompt, {})
    expect(requests.first[:tool_choice]).to eq("required")
    expect(requests.first[:tools].length).to eq(2)
    expect(result[:inner_thoughts].first[:outcome]).to eq("forced")
  end

  it "does not expose unavailable tools to the selector" do
    SiteSetting.chatbot_tools_low_trust = "calculate|news|escalate_to_staff"
    SiteSetting.chatbot_news_api_token = ""
    selection_response[:answers].delete(:tool_1)
    request =
      stub_request(:post, url)
        .with do |request|
          expect(JSON.parse(request.body).dig("state", "tools").map { |tool| tool["name"] }).to eq(
            ["calculate"],
          )
          true
        end
        .to_return(body: selection_response.to_json)
    capture_chat

    described_class.new({}).get_response(prompt, {})
    expect(request).to have_been_requested.once
  end

  it "does not evaluate an empty tool set" do
    SiteSetting.chatbot_tools_low_trust = ""
    capture_chat
    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first).not_to have_key(:tools)
    expect(result[:inner_thoughts].first[:outcome]).to eq("no_tools")
    expect(WebMock).not_to have_requested(:post, url)
  end

  it "filters field-collection prompts and prevents a removed tool from writing a field" do
    user = Fabricate(:user)
    field = Fabricate(:user_field, name: "Favourite colour", field_type: "text")
    other_field = Fabricate(:user_field, name: "Favourite animal", field_type: "text")
    SiteSetting.chatbot_tools_low_trust = "user_information"
    options = { private: true, user_id: user.id }
    removed_name = DiscourseChatbot::Tools::UserInformation.new(field.name, user.id).name
    kept_name = DiscourseChatbot::Tools::UserInformation.new(other_field.name, user.id).name
    selection_response[:answers] = { tool_0: judgment("irrelevant"), tool_1: judgment("relevant") }
    stub_request(:post, url).to_return(body: selection_response.to_json)
    tool_response = {
      "choices" => [
        {
          "finish_reason" => "tool_calls",
          "message" => {
            "content" => "",
            "tool_calls" => [
              {
                "id" => "call_removed",
                "type" => "function",
                "function" => {
                  "name" => removed_name,
                  "arguments" => '{"answer":"blue"}',
                },
              },
            ],
          },
        },
      ],
      "usage" => {
        "total_tokens" => 10,
      },
    }
    client
      .expects(:chat)
      .twice
      .with do |parameters:|
        requests << parameters.deep_dup
        true
      end
      .returns(tool_response, final_response)

    result =
      described_class.new(options).get_response(
        [{ role: "user", content: "My favourite animal is a cat" }],
        options,
      )

    expect(requests.first[:tools].map { |tool| tool[:function]["name"] }).to eq([kept_name])
    context = JSON.generate(requests.first[:messages])
    expect(context).to include(other_field.name)
    expect(context).not_to include(field.name)
    expect(UserCustomField.find_by(user_id: user.id, name: "user_field_#{field.id}")).to be_nil
    expect(result[:inner_thoughts].find { |entry| entry[:role] == "tool" }[:content]).to eq(
      I18n.t("chatbot.prompt.rag.call_function.error"),
    )
    expect(WebMock).to have_requested(:post, url).once
  end

  it "applies selection to extension tools without adding built-in permissions" do
    extension =
      Class.new(DiscourseChatbot::Tool) do
        define_method(:name) { "custom_lookup" }
        define_method(:description) { "Look up a custom reference" }
        define_method(:parameters) { [] }
        define_method(:required) { [] }
      end
    DiscourseChatbot::Tool.stubs(:descendants).returns([extension])
    selection_response[:answers][:tool_2] = judgment("irrelevant")
    request =
      stub_request(:post, url)
        .with do |request|
          expect(JSON.parse(request.body).dig("state", "tools").last["name"]).to eq("custom_lookup")
          true
        end
        .to_return(body: selection_response.to_json)
    capture_chat
    result = described_class.new({}).get_response(prompt, {})

    expect(result[:inner_thoughts].first[:removed_tools]).to eq(%w[wikipedia custom_lookup])
    expect(request).to have_been_requested.once
  ensure
    extension&.define_singleton_method(:available?) { |_opts| false }
  end
end

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
  let(:responses_final_response) do
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

  it "keeps definitions stable across tool-loop calls and exchanges with different selections" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6.1-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    next_selection = selection_response.deep_dup
    next_selection[:answers] = { tool_0: judgment("irrelevant"), tool_1: judgment("relevant") }
    stub_request(:post, url).to_return(
      { body: selection_response.to_json },
      { body: next_selection.to_json },
    )
    tool_response = {
      "status" => "completed",
      "output" => [
        {
          "type" => "function_call",
          "call_id" => "call_calculate",
          "name" => "calculate",
          "arguments" => '{"input":"2 + 2"}',
        },
      ],
      "usage" => {
        "total_tokens" => 10,
      },
    }
    capture_responses(tool_response, responses_final_response, responses_final_response)
    options = { type: DiscourseChatbot::MESSAGE, topic_or_channel_id: 7 }

    first_result = described_class.new(options).get_response(prompt.deep_dup, options)
    described_class.new(options).get_response(
      [*prompt, { role: "assistant", content: "Four." }, { role: "user", content: "What is pi?" }],
      options,
    )

    expect(requests.map { |request| request[:tools] }.uniq.length).to eq(1)
    expect(requests.first[:tools].map { |tool| tool[:name] }).to eq(%w[calculate wikipedia])
    expect(requests.map { |request| request[:prompt_cache_options] }.uniq).to eq(
      [{ mode: "implicit" }],
    )
    expect(
      requests.map { |request| request.dig(:input, 0, :content, 0, :prompt_cache_breakpoint) }.uniq,
    ).to eq([{ mode: "explicit" }])
    expect(requests.map { |request| request.dig(:tool_choice, :tools) }).to eq(
      [
        [{ type: "function", name: "calculate" }],
        [{ type: "function", name: "calculate" }],
        [{ type: "function", name: "wikipedia" }],
      ],
    )
    expect(requests.map { |request| request[:prompt_cache_key] }.uniq.length).to eq(1)
    expect(first_result[:reply]).to eq("Four.")
    expect(first_result[:inner_thoughts].first).to include(
      outcome: "restricted",
      requested_mode: "restrict_calls",
      effective_mode: "restrict_calls",
      removed_tools: [],
      disabled_tools: ["wikipedia"],
      retained_tools: ["calculate"],
      content: I18n.t("chatbot.inner_thoughts.tool_selection.restricted", tools: "wikipedia"),
    )
    expect(JSON.generate(requests.last[:input])).not_to include("disabled_tools", "tool_selection")
    expect(WebMock).to have_requested(:post, url).twice
  end

  it "disables all calls while keeping definitions when selection excludes every tool" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    selection_response[:answers][:tool_0] = judgment("irrelevant")
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_responses

    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:name] }).to eq(%w[calculate wikipedia])
    expect(requests.first[:tool_choice]).to eq("none")
    expect(result[:inner_thoughts].first).to include(disabled_tools: %w[calculate wikipedia])
    expect(JSON.generate(requests.first[:input])).to include(Date.current.iso8601)
  end

  it "retains definitions but disables calls on the last permitted model iteration" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 1
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_responses

    described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:name] }).to eq(%w[calculate wikipedia])
    expect(requests.first[:tool_choice]).to eq("none")
  end

  it "requires an allowed tool and restores the eligible set when every tool is rejected" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    SiteSetting.chatbot_tool_choice_first_iteration = "force_a_tool"
    all_removed = selection_response.deep_dup
    all_removed[:answers][:tool_0] = judgment("irrelevant")
    stub_request(:post, url).to_return(
      { body: selection_response.to_json },
      { body: all_removed.to_json },
    )
    capture_responses(responses_final_response, responses_final_response)

    described_class.new({}).get_response(prompt.deep_dup, {})
    result = described_class.new({}).get_response(prompt.deep_dup, {})

    expect(requests.first[:tool_choice]).to eq(
      type: "allowed_tools",
      mode: "required",
      tools: [{ type: "function", name: "calculate" }],
    )
    expect(requests.last[:tool_choice]).to eq(
      type: "allowed_tools",
      mode: "required",
      tools: %w[calculate wikipedia].map { |name| { type: "function", name: name } },
    )
    expect(result[:inner_thoughts].first).to include(
      outcome: "forced",
      disabled_tools: [],
      protected_tools: %w[calculate wikipedia],
    )
  end

  it "keeps a forced local search callable in restrict_calls mode" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    SiteSetting.chatbot_tool_choice_first_iteration = "force_local_forum_search"
    SiteSetting.chatbot_embeddings_enabled = true
    SiteSetting.chatbot_tools_low_trust = "calculate|wikipedia|local_forum_search"
    selection_response[:answers][:tool_2] = judgment("irrelevant")
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_responses

    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tool_choice]).to eq(type: "function", name: "local_forum_search")
    expect(result[:inner_thoughts].first).to include(
      disabled_tools: ["wikipedia"],
      retained_tools: %w[calculate local_forum_search],
      protected_tools: ["local_forum_search"],
    )
  end

  [
    %w[gpt-4.1-mini remove_definitions],
    %w[gpt-6-sol remove_definitions],
    %w[gpt-6-sol restrict_calls],
  ].each do |model, mode|
    it "ignores an ineligible forced local search with #{model} and #{mode}" do
      SiteSetting.chatbot_open_ai_model_low_trust = model
      SiteSetting.chatbot_system_one_tool_selection_mode = mode
      SiteSetting.chatbot_tool_choice_first_iteration = "force_local_forum_search"
      stub_request(:post, url).to_return(body: selection_response.to_json)
      if model == "gpt-4.1-mini"
        client
          .expects(:chat)
          .twice
          .with do |parameters:|
            requests << parameters.deep_dup
            true
          end
          .returns(final_response)
      else
        capture_responses(responses_final_response, responses_final_response)
      end

      SiteSetting.chatbot_tools_low_trust = "calculate|wikipedia|local_forum_search"
      SiteSetting.chatbot_embeddings_enabled = false
      described_class.new({}).get_response(prompt.deep_dup, {})

      SiteSetting.chatbot_tools_low_trust = "calculate|wikipedia"
      SiteSetting.chatbot_embeddings_enabled = true
      described_class.new({}).get_response(prompt.deep_dup, {})

      expected_choice =
        if mode == "restrict_calls"
          { type: "allowed_tools", mode: "auto", tools: [{ type: "function", name: "calculate" }] }
        end
      expect(requests.map { |request| request[:tool_choice] }).to eq(
        [expected_choice, expected_choice],
      )
    end
  end

  it "falls back to definition removal for Chat Completions and reports the effective mode" do
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    stub_request(:post, url).to_return(body: selection_response.to_json)
    capture_chat

    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:function]["name"] }).to eq(["calculate"])
    expect(result[:inner_thoughts].first).to include(
      outcome: "removed",
      requested_mode: "restrict_calls",
      effective_mode: "remove_definitions",
      mode_fallback_reason: "unsupported_configuration",
      removed_tools: ["wikipedia"],
    )
  end

  it "keeps all definitions and callable tools when System One fails in restrict_calls mode" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    stub_request(:post, url).to_return(status: 503, body: "unavailable")
    capture_responses

    result = described_class.new({}).get_response(prompt, {})

    expect(requests.first[:tools].map { |tool| tool[:name] }).to eq(%w[calculate wikipedia])
    expect(requests.first[:tool_choice]).to eq(
      type: "allowed_tools",
      mode: "auto",
      tools: %w[calculate wikipedia].map { |name| { type: "function", name: name } },
    )
    expect(result[:inner_thoughts].first).to include(outcome: "fallback", disabled_tools: [])
  end

  it "blocks execution of excluded field tools even though their definitions were supplied" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-6-sol"
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
    SiteSetting.chatbot_tools_low_trust = "calculate|user_information"
    user = Fabricate(:user)
    field = Fabricate(:user_field, name: "Favourite colour", field_type: "text")
    excluded_name = DiscourseChatbot::Tools::UserInformation.new(field.name, user.id).name
    stub_request(:post, url).to_return(body: selection_response.to_json)
    excluded_call = {
      "status" => "completed",
      "output" => [
        {
          "type" => "function_call",
          "call_id" => "call_excluded",
          "name" => excluded_name,
          "arguments" => '{"answer":"blue"}',
        },
      ],
      "usage" => {
        "total_tokens" => 10,
      },
    }
    capture_responses(excluded_call, responses_final_response)
    options = { private: true, user_id: user.id }

    result = described_class.new(options).get_response(prompt, options)

    expect(requests.first[:tools].map { |tool| tool[:name] }).to eq(["calculate", excluded_name])
    expect(requests.first[:tool_choice]).to eq(
      type: "allowed_tools",
      mode: "auto",
      tools: [{ type: "function", name: "calculate" }],
    )
    expect(JSON.generate(requests.first[:input])).not_to include(field.name)
    expect(UserCustomField.find_by(user_id: user.id, name: "user_field_#{field.id}")).to be_nil
    expect(result[:inner_thoughts].find { |entry| entry[:role] == "tool" }[:content]).to eq(
      I18n.t("chatbot.prompt.rag.call_function.error"),
    )
  end

  it "does not evaluate or add diagnostics when the feature is disabled" do
    SiteSetting.chatbot_system_one_tool_selection_enabled = false
    SiteSetting.chatbot_system_one_tool_selection_mode = "restrict_calls"
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

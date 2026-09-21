# frozen_string_literal: true
require_relative "../plugin_helper"
require_relative "../support/tool_selection_helpers"

describe DiscourseChatbot::ToolSelector do
  include DiscourseChatbot::ToolSelectionHelpers

  let(:tools) do
    [DiscourseChatbot::Tools::Calculator.new, DiscourseChatbot::Tools::Wikipedia.new].index_by(
      &:name
    )
  end
  let(:definitions) do
    tools.values.map { |tool| DiscourseChatbot::Tools::Parser.tool_to_json(tool) }
  end
  let(:prompt) { [{ role: "user", content: "What is 2 + 2?" }] }
  let(:url) { SiteSetting.chatbot_system_one_url }
  let(:response) do
    {
      model: "jev-1.13.0",
      answers: {
        tool_0: judgment("relevant"),
        tool_1: judgment("irrelevant"),
      },
      usage: {
        input_tokens: 100,
        output_tokens: 30,
      },
    }
  end

  before { SiteSetting.chatbot_system_one_key = "test-key" }

  it "removes only confidently irrelevant tools and reports the actual selection" do
    SiteSetting.chatbot_system_one_tool_selection_context = "Use calculation for arithmetic."
    request =
      stub_request(:post, url)
        .with do |request|
          body = JSON.parse(request.body)
          expect(body.dig("state", "query")).to eq("What is 2 + 2?")
          expect(body.dig("state", "administrator_guidance")).to eq(
            SiteSetting.chatbot_system_one_tool_selection_context,
          )
          expect(body["questions"].keys).to eq(%w[tool_0 tool_1])
          expect(body.dig("state", "tools").map { |tool| tool["name"] }).to eq(
            %w[calculate wikipedia],
          )
          true
        end
        .to_return(body: response.to_json)

    result = evaluate

    expect(result[:retained_tool_names]).to eq(["calculate"])
    expect(result[:audit]).to include(
      removed_tools: ["wikipedia"],
      content: "I removed these tools from the available set based on the query: wikipedia.",
      model: "jev-1.13.0",
      usage: response[:usage].stringify_keys,
    )
    expect(request).to have_been_requested.once
  end

  it "keeps uncertain and below-threshold tools, including when the threshold is zero" do
    response[:answers] = { tool_0: judgment("irrelevant", 0.8), tool_1: judgment("unclear") }
    stub_request(:post, url).to_return(body: response.to_json)

    expect(evaluate[:retained_tool_names]).to eq(tools.keys)
    SiteSetting.chatbot_system_one_tool_removal_threshold = 0
    expect(evaluate[:retained_tool_names]).to eq(["wikipedia"])
  end

  it "can remove every tool unless an administrator forces a tool call" do
    response[:answers][:tool_0] = judgment("irrelevant")
    stub_request(:post, url).to_return(body: response.to_json)
    expect(evaluate[:retained_tool_names]).to eq([])

    SiteSetting.chatbot_tool_choice_first_iteration = "force_a_tool"
    expect(evaluate).to include(retained_tool_names: tools.keys)
    expect(evaluate[:audit]).to include(
      outcome: "forced",
      removed_tools: [],
      protected_tools: tools.keys,
    )
  end

  it "keeps a forced local search tool even when classified irrelevant" do
    tool = DiscourseChatbot::Tools::ForumSearch.new
    tools["local_forum_search"] = tool
    response[:answers][:tool_2] = judgment("irrelevant")
    SiteSetting.chatbot_tool_choice_first_iteration = "force_local_forum_search"
    stub_request(:post, url).to_return(body: response.to_json)

    expect(evaluate[:retained_tool_names]).to eq(%w[calculate local_forum_search])
  end

  it "falls back atomically on provider errors and malformed or incomplete answers" do
    stub_request(:post, url).to_return(
      { status: 503, body: "unavailable" },
      { body: "not json" },
      {
        body:
          response.deep_merge(answers: { tool_1: { probabilities: { irrelevant: 2 } } }).to_json,
      },
      { body: response.merge(answers: { tool_1: judgment("irrelevant") }).to_json },
    )
    4.times do
      result = evaluate
      expect(result[:retained_tool_names]).to eq(tools.keys)
      expect(result[:audit]).to include(outcome: "fallback", removed_tools: [])
    end
  end

  it "falls back on timeouts" do
    stub_request(:post, url).to_timeout
    expect(evaluate[:audit]).to include(outcome: "fallback", retained_tools: tools.keys)
  end

  it "skips evaluation for missing credentials, empty queries, and oversized context" do
    SiteSetting.chatbot_system_one_key = ""
    expect(evaluate[:audit][:reason]).to eq("not_configured")
    SiteSetting.chatbot_system_one_key = "test-key"
    expect(evaluate(prompt: [])[:audit][:reason]).to eq("empty_query")
    expect(evaluate(prompt: [{ role: "user", content: "x" * 40_001 }])[:audit][:reason]).to eq(
      "context_too_large",
    )
    SiteSetting.chatbot_system_one_tool_selection_context = "x" * 4001
    expect(evaluate[:audit][:reason]).to eq("context_too_large")
    expect(WebMock).not_to have_requested(:post, url)
  end

  it "uses the independent post history window and excludes hidden, deleted, future, and audit posts" do
    bot = Fabricate(:user)
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic)
    preceding = Fabricate(:post, topic: topic, user: bot)
    Fabricate(:post, topic: topic, hidden: true)
    Fabricate(:post, topic: topic, deleted_at: Time.current)
    Fabricate(
      :post,
      topic: topic,
      user: bot,
      raw: "#{DiscourseChatbot::INNER_THOUGHTS_POST_PREFIX}[]",
    )
    current = Fabricate(:post, topic: topic, raw: "Please explain that")
    Fabricate(:post, topic: topic)
    SiteSetting.chatbot_system_one_tool_selection_look_back = 1
    request =
      stub_request(:post, url)
        .with do |request|
          state = JSON.parse(request.body).fetch("state")
          expect(state["query"]).to eq(current.raw)
          expect(state["conversation"]).to include(
            "title" => topic.title,
            "preceding_messages" => [{ "role" => "assistant", "text" => preceding.raw }],
          )
          true
        end
        .to_return(body: response.to_json)

    evaluate(
      opts: {
        type: DiscourseChatbot::POST,
        reply_to_message_or_post_id: current.id,
        bot_user_id: bot.id,
      },
    )
    expect(request).to have_been_requested.once
  end

  it "limits Chat history to the current thread and supports a zero look-back" do
    SiteSetting.chatbot_system_one_tool_selection_look_back = 1
    channel = Fabricate(:chat_channel)
    thread = Fabricate(:chat_thread, channel: channel)
    other_thread = Fabricate(:chat_thread, channel: channel)
    previous = Fabricate(:chat_message, chat_channel: channel, thread: thread)
    Fabricate(:chat_message, chat_channel: channel, thread: other_thread)
    current = Fabricate(:chat_message, chat_channel: channel, thread: thread)
    states = []
    stub_request(:post, url)
      .with do |request|
        states << JSON.parse(request.body)["state"]
        true
      end
      .to_return(body: response.to_json)
    options = { type: DiscourseChatbot::MESSAGE, reply_to_message_or_post_id: current.id }
    evaluate(opts: options)
    SiteSetting.chatbot_system_one_tool_selection_look_back = 0
    evaluate(opts: options)

    expect(states.first.dig("conversation", "preceding_messages")).to eq(
      [{ "role" => "user", "text" => previous.message }],
    )
    expect(states.last.dig("conversation", "preceding_messages")).to eq([])
    expect(states.last["query"]).to eq(current.message)
  end

  it "marks side-effect tools for action-intent selection" do
    field = Fabricate(:user_field, name: "Favourite colour", field_type: "text")
    user = Fabricate(:user)
    tool = DiscourseChatbot::Tools::UserInformation.new(field.name, user.id)
    tools[tool.name] = tool
    response[:answers][:tool_2] = judgment("irrelevant")
    stub_request(:post, url)
      .with do |request|
        body = JSON.parse(request.body)
        expect(body.dig("state", "tools", 2, "requires_user_intent")).to eq(true)
        expect(body.dig("questions", "tool_2", "instructions", "task")).to include("hypothetically")
        true
      end
      .to_return(body: response.to_json)

    expect(evaluate[:audit][:removed_tools]).to eq(["wikipedia", tool.name])
  end
end

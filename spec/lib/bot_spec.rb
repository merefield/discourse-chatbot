# frozen_string_literal: true
require_relative "../plugin_helper"

RSpec.configure do |config|
  config.prepend_before(:suite) do
    User.find_by(username: "Chatbot") || Fabricate(:user, username: "Chatbot")
  end
end

describe ::DiscourseChatbot::Bot do
  let(:opts) { {} }
  let(:rag) { described_class.new(opts) }
  let(:llm_function_response) { get_chatbot_output_fixture("llm_function_response") }
  let(:llm_final_response) { get_chatbot_output_fixture("llm_final_response") }
  let(:post_ids_found) { [] }
  let(:topic_ids_found) { [111, 222, 3333] }
  let(:client) { mock }
  let(:responses_api) { mock }

  fab!(:topic_user, :user)
  fab!(:post_user, :user)
  fab!(:topic_1) { Fabricate(:topic, id: 112, user: topic_user) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, user: post_user, post_number: 2) }

  before do
    SiteSetting.discourse_local_dates_enabled = false
    SiteSetting.chatbot_tools_low_trust =
      (::DiscourseChatbot::Tool::BUILT_IN_TOOL_NAMES - ["user_information"]).join("|")
    OpenAI::Client.stubs(:new).returns(client)
    client.stubs(:responses).returns(responses_api)
  end
  let(:post_ids_found_2) { [post_1.id] }
  let(:res) do
    "the value is 90 and I found that information in [this topic](https://#{Discourse.current_hostname}/t/slug/112)"
  end
  let(:res_2) do
    "the value is 99 and I found that information in [this post](https://#{Discourse.current_hostname}/t/slug/112/2)"
  end

  let(:completion_response) do
    lambda do |content, total_tokens: 2, logprobs: nil|
      choice = { "finish_reason" => "stop", "message" => { "content" => content } }
      choice["logprobs"] = { "content" => logprobs } if logprobs

      { "choices" => [choice], "usage" => { "total_tokens" => total_tokens } }
    end
  end
  let(:advanced_outcome) do
    lambda do |key, **options|
      {
        type: "advanced_local_reasoning_outcome",
        content:
          I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.outcomes.#{key}", **options),
      }
    end
  end

  it "consumes accumulated tokens when a response fails" do
    SiteSetting.chatbot_quota_basis = "tokens"
    user = Fabricate(:user)
    bot_user = Fabricate(:user)
    post = Fabricate(:post, user: user)
    quota =
      UserCustomField.create!(
        user_id: user.id,
        name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
        value: "100",
      )
    failed_bot_class =
      Class.new(described_class) do
        define_method(:initialize) { @total_tokens = 0 }
        define_method(:get_response) do |*|
          @total_tokens = 10
          raise ::DiscourseChatbot::Bot::TokenBudgetError, "budget reached"
        end
      end
    bot_options = {
      type: ::DiscourseChatbot::POST,
      user_id: user.id,
      bot_user_id: bot_user.id,
      reply_to_message_or_post_id: post.id,
      original_post_number: post.post_number,
      category_id: post.topic.category_id,
    }

    expect { failed_bot_class.new.ask(bot_options) }.to raise_error(
      ::DiscourseChatbot::Bot::TokenBudgetError,
      "budget reached",
    )
    expect(quota.reload.value).to eq("90")
  end

  it "calls a tool on returning a tool request from LLN" do
    query = [{ role: "user", content: "merefield said what is 3 * 23.452432?" }]

    system_entry = {
      role: "developer",
      content:
        "You are a helpful assistant. You have tools that give you the power to get newer information. Only use the tools you have been provided with. When referring to users by name, include an @ symbol directly in front of their username. Only respond to the last question, using the prior information as context, if appropriate.",
    }
    first_query = get_chatbot_input_fixture("llm_first_query").unshift(system_entry)
    second_query = get_chatbot_input_fixture("llm_second_query").unshift(system_entry)

    described_class
      .any_instance
      .expects(:create_chat_completion)
      .with(first_query, true, 1)
      .returns(llm_function_response)
    described_class
      .any_instance
      .expects(:create_chat_completion)
      .with(second_query, true, 2)
      .returns(llm_final_response)

    expect(rag.get_response(query, opts)[:reply]).to eq(
      llm_final_response["choices"][0]["message"]["content"],
    )
  end

  it "aggregates usage statistics without adding them to the active model context" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    requests = []

    client
      .expects(:chat)
      .times(2)
      .with do |args|
        requests << args[:parameters]
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
                    "id" => "call_1",
                    "type" => "function",
                    "function" => {
                      "name" => "calculate",
                      "arguments" => '{"input":"2 + 2"}',
                    },
                  },
                ],
              },
            },
          ],
          "usage" => {
            "prompt_tokens" => 100,
            "completion_tokens" => 10,
            "total_tokens" => 110,
            "prompt_tokens_details" => {
              "cached_tokens" => 60,
              "cache_write_tokens" => 20,
            },
          },
        },
        {
          "choices" => [
            { "finish_reason" => "stop", "message" => { "content" => "The answer is 4." } },
          ],
          "usage" => {
            "prompt_tokens" => 150,
            "completion_tokens" => 20,
            "total_tokens" => 170,
            "prompt_tokens_details" => {
              "cached_tokens" => 100,
            },
            "completion_tokens_details" => {
              "reasoning_tokens" => 5,
            },
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "What is 2 + 2?" }], opts)
    statistics = response[:usage_statistics]

    expect(statistics).to eq(
      {
        type: "usage_statistics",
        model: rag.model_name,
        input_tokens: 250,
        cached_input_tokens: 160,
        cached_input_percentage: 64.0,
        cache_write_tokens: 20,
        output_tokens: 30,
        reasoning_tokens: 5,
        total_tokens: 280,
      },
    )
    expect(JSON.generate(requests.second[:messages])).not_to include(statistics[:type])
    expect(JSON.generate(response[:inner_thoughts])).not_to include(statistics[:type])
  end

  it "optimizes official Chat Completions requests for prompt caching" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 1
    request = nil
    bot_opts = { type: ::DiscourseChatbot::POST, topic_or_channel_id: 42, trust_level: "low" }

    client
      .expects(:chat)
      .with do |args|
        request = args[:parameters]
        true
      end
      .returns(
        completion_response.call("Done", total_tokens: 250).deep_merge(
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 50,
            "prompt_tokens_details" => {
              "cached_tokens" => 120,
              "cache_write_tokens" => 30,
            },
          },
        ),
      )

    response =
      described_class.new(bot_opts).get_response([{ role: "user", content: "Help me" }], bot_opts)

    expect(request[:prompt_cache_key]).to match(/\Adiscourse-chatbot:[0-9a-f]{40}\z/)
    expect(request[:messages]).to eq(
      [
        { role: "developer", content: I18n.t("chatbot.prompt.system.rag.open") },
        { role: "user", content: "Help me" },
      ],
    )
    expect(request).to include(tool_choice: "none")
    expect(request[:tools]).to be_present
    expect(response).to include(cached_tokens: 120, cache_write_tokens: 30)
    expect(response[:usage_statistics]).to include(
      input_tokens: 200,
      cached_input_tokens: 120,
      cached_input_percentage: 60.0,
      cache_write_tokens: 30,
      output_tokens: 50,
      total_tokens: 250,
    )
  end

  it "uses an explicit stable-prefix breakpoint for GPT-5.6 Responses requests" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.6"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 1
    request = nil
    bot_opts = {
      type: ::DiscourseChatbot::MESSAGE,
      topic_or_channel_id: 7,
      thread_id: 9,
      trust_level: "low",
    }

    responses_api
      .expects(:create)
      .with do |args|
        request = args[:parameters]
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            { "type" => "message", "content" => [{ "type" => "output_text", "text" => "Done" }] },
          ],
          "usage" => {
            "total_tokens" => 200,
            "input_tokens" => 180,
            "output_tokens" => 20,
            "input_tokens_details" => {
              "cached_tokens" => 150,
              "cache_write_tokens" => 25,
            },
            "output_tokens_details" => {
              "reasoning_tokens" => 12,
            },
          },
        },
      )

    response =
      described_class.new(bot_opts).get_response([{ role: "user", content: "Help me" }], bot_opts)

    stable_content = request.dig(:input, 0, :content, 0)
    expect(request[:prompt_cache_key]).to match(/\Adiscourse-chatbot:[0-9a-f]{40}\z/)
    expect(request[:prompt_cache_options]).to eq(mode: "implicit")
    expect(stable_content[:prompt_cache_breakpoint]).to eq(mode: "explicit")
    expect(request.dig(:input, -1, :content, 0, :text)).to eq("Help me")
    expect(request).to include(tool_choice: "none")
    expect(request[:tools]).to be_present
    expect(response).to include(cached_tokens: 150, cache_write_tokens: 25)
    expect(response[:usage_statistics]).to include(
      input_tokens: 180,
      cached_input_tokens: 150,
      cached_input_percentage: 83.3,
      cache_write_tokens: 25,
      output_tokens: 20,
      reasoning_tokens: 12,
      total_tokens: 200,
    )
  end

  it "places a date-only context before the conversation when calculate is unavailable" do
    SiteSetting.chatbot_tools_low_trust = ""
    Date.stubs(:current).returns(Date.new(2026, 8, 16))
    request = nil

    client
      .expects(:chat)
      .with do |args|
        request = args[:parameters]
        true
      end
      .returns(completion_response.call("Done"))

    response = described_class.new({}).get_response([{ role: "user", content: "Help me" }], {})

    expect(response[:reply]).to eq("Done")
    expect(request[:messages]).to eq(
      [
        { role: "developer", content: I18n.t("chatbot.prompt.system.rag.open") },
        { role: "developer", content: "The current date is 2026-08-16." },
        { role: "user", content: "Help me" },
      ],
    )
  end

  it "does not send OpenAI-specific cache parameters to a custom endpoint" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.6"
    SiteSetting.chatbot_open_ai_model_custom_url_low_trust = "https://llm.example.com/v1"
    bot_opts = { type: ::DiscourseChatbot::POST, topic_or_channel_id: 42, trust_level: "low" }
    bot = described_class.new(bot_opts)

    parameters =
      bot.responses_parameters(
        [{ role: "developer", content: "Stable", prompt_cache_breakpoint: true }],
      )

    expect(parameters).not_to have_key(:prompt_cache_key)
    expect(parameters).not_to have_key(:prompt_cache_options)
    expect(parameters.dig(:input, 0, :content, 0)).to eq(type: "input_text", text: "Stable")
  end

  it "requires a tool during the first iteration when configured" do
    SiteSetting.chatbot_tool_choice_first_iteration = "force_a_tool"

    client
      .expects(:chat)
      .with do |args|
        parameters = args[:parameters]
        parameters[:tool_choice] == "required" && parameters[:tools].present?
      end
      .returns(completion_response.call("Done"))

    expect(rag.get_response([{ role: "user", content: "Help me" }], opts)[:reply]).to eq("Done")
  end

  it "returns malformed tool arguments to the model as a tool error" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    requests = []

    responses_api
      .expects(:create)
      .times(2)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "calculate",
              "arguments" => "{",
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "I could not calculate it." }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Calculate something" }], opts)

    expect(response[:reply]).to eq("I could not calculate it.")
    expect(requests.second[:input].last).to eq(
      {
        type: "function_call_output",
        call_id: "call_1",
        output: I18n.t("chatbot.prompt.rag.call_function.error"),
      },
    )
  end

  it "returns a single successful image tool result directly" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    image_markdown = "![generated image](upload://image.png)"
    ::DiscourseChatbot::Tools::Paint
      .any_instance
      .stubs(:process)
      .returns({ answer: image_markdown, token_usage: 10 })

    responses_api
      .expects(:create)
      .once
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "paint_picture",
              "arguments" => "{\"description\":\"an image\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Paint an image" }], opts)

    expect(response[:reply]).to eq(image_markdown)
  end

  it "continues mixed tool batches when the image result is last" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    image_markdown = "![generated image](upload://image.png)"
    ::DiscourseChatbot::Tools::Paint
      .any_instance
      .stubs(:process)
      .returns({ answer: image_markdown, token_usage: 10 })
    requests = []

    responses_api
      .expects(:create)
      .times(2)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "calculate",
              "arguments" => "{\"input\":\"2 + 2\"}",
            },
            {
              "type" => "function_call",
              "call_id" => "call_2",
              "name" => "paint_picture",
              "arguments" => "{\"description\":\"the number four\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "The result is 4, shown below." }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Calculate and paint" }], opts)

    expect(response[:reply]).to eq("The result is 4, shown below.")
    expect(requests.second[:input].last(2)).to eq(
      [
        { type: "function_call_output", call_id: "call_1", output: "4" },
        { type: "function_call_output", call_id: "call_2", output: image_markdown },
      ],
    )
  end

  it "returns correct status for a response that includes and illegal topic id" do
    result = rag.legal_post_urls?(res, post_ids_found, topic_ids_found)

    expect(result).to eq(false)
  end

  it "returns correct status for a response that includes a legal post id" do
    expect(post_1).to be_present
    result = rag.legal_post_urls?(res_2, post_ids_found_2, topic_ids_found)
    expect(result).to eq(true)
  end

  it "correctly identifies a legal post id in a url in a response" do
    expect(
      described_class.new({}).legal_post_urls?("hello /t/slug/112/2", [post_1.id], [topic_1.id]),
    ).to eq(true)
  end

  it "correctly skips a full url check if a response is blank" do
    expect(described_class.new({}).legal_post_urls?("", [post_1.id], [topic_1.id])).to eq(true)
  end

  it "correctly identifies an illegal topic id in a url in a response" do
    expect(
      described_class.new({}).legal_post_urls?("hello /t/slug/113/2", [post_1.id], [topic_1.id]),
    ).to eq(false)
  end

  it "does not trust forum ids on another host" do
    response = "See https://evil.example/t/slug/#{topic_1.id}"

    expect(described_class.new({}).legal_post_urls?(response, [], [topic_1.id])).to eq(true)
    expect(described_class.new({}).legal_non_post_urls?(response, [])).to eq(false)
  end

  it "rejects malformed forum paths with an allowed topic id" do
    response = "See https://#{Discourse.current_hostname}/t/slug/#{topic_1.id}/unexpected/path"

    expect(described_class.new({}).legal_post_urls?(response, [], [topic_1.id])).to eq(false)
  end

  it "accepts a relative forum URL with an allowed topic id" do
    response = "See /t/slug/#{topic_1.id}"

    expect(described_class.new({}).legal_post_urls?(response, [], [topic_1.id])).to eq(true)
  end

  it "correctly identifies an illegal non-post url in a response" do
    expect(
      described_class.new({}).legal_non_post_urls?(
        "hello https://someplace.com/t/slug/113/2 try looking at https://notanexample.com it's great",
        %w[https://example.com https://otherexample.com],
      ),
    ).to eq(false)
  end

  it "correctly identifies a legal non-post url in a response" do
    expect(
      described_class.new({}).legal_non_post_urls?(
        "hello https://#{Discourse.current_hostname}/t/slug/113/2 try looking at https://example.com it's great",
        %w[https://example.com https://otherexample.com],
      ),
    ).to eq(true)
  end

  it "normalizes trusted non-post URLs before comparing them" do
    response = "See [the documentation](https://EXAMPLE.com/docs/#install)."

    expect(
      described_class.new({}).legal_non_post_urls?(response, ["https://example.com/docs"]),
    ).to eq(true)
  end

  it "requires query strings to match trusted non-post URLs" do
    response = "See https://example.com/docs?section=other"

    expect(
      described_class.new({}).legal_non_post_urls?(
        response,
        ["https://example.com/docs?section=install"],
      ),
    ).to eq(false)
  end

  it "allows a trusted external URL that resembles a Discourse topic" do
    response = "See https://meta.example.com/t/slug/123"

    expect(described_class.new({}).legal_post_urls?(response, [], [])).to eq(true)
    expect(
      described_class.new({}).legal_non_post_urls?(response, [response.delete_prefix("See ")]),
    ).to eq(true)
  end

  it "uses the responses api for reasoning models" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_open_ai_model_reasoning_level = "medium"
    SiteSetting.chatbot_open_ai_model_verbosity = "high"

    client.expects(:chat).never
    responses_api
      .expects(:create)
      .with do |args|
        parameters = args[:parameters]

        expect(parameters[:model]).to eq("gpt-5.4-mini")
        expect(parameters[:reasoning]).to eq({ effort: "medium", summary: "auto" })
        expect(parameters[:text]).to eq({ verbosity: "high" })
        expect(parameters[:max_output_tokens]).to eq(25_000)
        expect(parameters[:input]).to eq(
          [{ role: "user", content: [{ type: "input_text", text: "Hello" }] }],
        )
        true
      end
      .returns(
        {
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "Hello back" }],
            },
          ],
          "usage" => {
            "total_tokens" => 21,
          },
        },
      )

    response = rag.create_chat_completion([{ role: "user", content: "Hello" }], false, 1)

    expect(response.dig("choices", 0, "message", "content")).to eq("Hello back")
    expect(response.dig("choices", 0, "finish_reason")).to eq("stop")
  end

  it "normalizes responses api tool calls into the existing rag shape" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"

    responses_api.expects(:create).returns(
      {
        "output" => [
          {
            "type" => "function_call",
            "id" => "fc_1",
            "call_id" => "call_1",
            "name" => "calculator",
            "arguments" => "{\"expression\":\"2+2\"}",
          },
        ],
        "usage" => {
          "total_tokens" => 9,
        },
      },
    )

    response = rag.create_chat_completion([{ role: "user", content: "Calculate" }], false, 1)

    expect(response.dig("choices", 0, "finish_reason")).to eq("tool_calls")
    expect(response.dig("choices", 0, "message", "tool_calls")).to eq(
      [
        {
          "id" => "call_1",
          "type" => "function",
          "function" => {
            "name" => "calculator",
            "arguments" => "{\"expression\":\"2+2\"}",
          },
        },
      ],
    )
  end

  it "preserves reasoning items across tool calls and returns their summaries" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    encrypted_content = "encrypted-state"

    first_reasoning_item = {
      "id" => "rs_1",
      "type" => "reasoning",
      "encrypted_content" => encrypted_content,
      "summary" => [{ "type" => "summary_text", "text" => "I need to calculate the expression." }],
    }
    final_reasoning_item = {
      "id" => "rs_2",
      "type" => "reasoning",
      "summary" => [
        { "type" => "summary_text", "text" => "The calculation result is sufficient to answer." },
      ],
    }
    requests = []

    responses_api
      .expects(:create)
      .twice
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "output" => [
            first_reasoning_item,
            {
              "type" => "function_call",
              "id" => "fc_1",
              "call_id" => "call_1",
              "name" => "calculate",
              "arguments" => "{\"input\":\"2 + 2\"}",
              "status" => "completed",
            },
          ],
          "status" => "completed",
          "usage" => {
            "total_tokens" => 9,
          },
        },
        {
          "output" => [
            final_reasoning_item,
            {
              "type" => "message",
              "role" => "assistant",
              "content" => [{ "type" => "output_text", "text" => "The answer is 4." }],
            },
          ],
          "status" => "completed",
          "usage" => {
            "total_tokens" => 9,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "What is 2 + 2?" }], opts)

    expect(response[:reply]).to eq("The answer is 4.")
    expect(
      response[:inner_thoughts].select { |thought| thought[:type] == "reasoning_summary" },
    ).to eq(
      [
        { type: "reasoning_summary", content: "I need to calculate the expression." },
        { type: "reasoning_summary", content: "The calculation result is sufficient to answer." },
      ],
    )
    expect(requests.second[:input].last(3)).to eq(
      [
        first_reasoning_item.deep_symbolize_keys,
        {
          type: "function_call",
          id: "fc_1",
          call_id: "call_1",
          name: "calculate",
          arguments: "{\"input\":\"2 + 2\"}",
          status: "completed",
        },
        { type: "function_call_output", call_id: "call_1", output: "4" },
      ],
    )
    expect(JSON.generate(response[:inner_thoughts])).not_to include(encrypted_content)
  end

  it "continues after a reasoning-only response and includes its summary in inner thoughts" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    reasoning_item = {
      "id" => "rs_1",
      "type" => "reasoning",
      "summary" => [
        { "type" => "summary_text", "text" => "I need another step before answering." },
      ],
    }
    requests = []

    responses_api
      .expects(:create)
      .twice
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [reasoning_item],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "Final answer" }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Think this through" }], opts)

    expect(response[:reply]).to eq("Final answer")
    expect(response[:inner_thoughts]).to eq(
      [{ type: "reasoning_summary", content: "I need another step before answering." }],
    )
    expect(requests.second[:input].last).to eq(reasoning_item.deep_symbolize_keys)
  end

  it "rejects a completed responses api message without visible content" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    responses_api.expects(:create).returns(
      {
        "status" => "completed",
        "output" => [{ "type" => "message", "content" => [] }],
        "usage" => {
          "total_tokens" => 2,
        },
      },
    )

    expect do rag.get_response([{ role: "user", content: "Answer me" }], opts) end.to raise_error(
      ::DiscourseChatbot::Bot::ResponsesApiError,
      "OpenAI Responses API completed without visible message content",
    )
  end

  it "returns visible text from responses api output used by auxiliary generations" do
    response = {
      "status" => "completed",
      "output" => [
        {
          "type" => "message",
          "content" => [{ "type" => "output_text", "text" => "Generated title" }],
        },
      ],
    }

    expect(rag.responses_text(response)).to eq("Generated title")
  end

  it "returns visible text when a responses api response reaches its output budget" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"

    responses_api.expects(:create).returns(
      {
        "status" => "incomplete",
        "incomplete_details" => {
          "reason" => "max_output_tokens",
        },
        "output" => [
          {
            "type" => "message",
            "content" => [{ "type" => "output_text", "text" => "Partial answer" }],
          },
        ],
        "usage" => {
          "total_tokens" => 25_000,
        },
      },
    )

    response = rag.get_response([{ role: "user", content: "Write a long answer" }], opts)

    expect(response[:reply]).to eq("Partial answer")
  end

  it "records token usage before validating a responses api response" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    responses_api.expects(:create).returns(
      {
        "status" => "incomplete",
        "incomplete_details" => {
          "reason" => "max_output_tokens",
        },
        "output" => [],
        "usage" => {
          "total_tokens" => 10,
        },
      },
    )

    expect do
      rag.get_response([{ role: "user", content: "Think this through" }], opts)
    end.to raise_error(::DiscourseChatbot::Bot::TokenBudgetError)

    expect(rag.total_tokens).to eq(10)
  end

  it "preserves reasoning summaries when a responses api response exhausts its output budget" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    summary_text = "I used the available budget to investigate the question."
    responses_api.expects(:create).returns(
      {
        "status" => "incomplete",
        "incomplete_details" => {
          "reason" => "max_output_tokens",
        },
        "output" => [
          {
            "type" => "reasoning",
            "summary" => [{ "type" => "summary_text", "text" => summary_text }],
          },
        ],
        "usage" => {
          "total_tokens" => 25_000,
        },
      },
    )

    expect do
      rag.get_response([{ role: "user", content: "Think this through" }], opts)
    end.to raise_error(::DiscourseChatbot::Bot::TokenBudgetError)

    expect(rag.inner_thoughts).to eq([{ type: "reasoning_summary", content: summary_text }])
  end

  it "stops a reasoning continuation after reaching the aggregate chain budget" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_open_ai_max_chain_tokens = 5
    responses_api
      .expects(:create)
      .once
      .returns(
        {
          "status" => "completed",
          "output" => [{ "type" => "reasoning", "summary" => [] }],
          "usage" => {
            "total_tokens" => 5,
          },
        },
      )

    expect do
      rag.get_response([{ role: "user", content: "Think this through" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::Bot::TokenBudgetError,
      "OpenAI response exceeded the configured chatbot_open_ai_max_chain_tokens budget",
    )
  end

  it "keeps the simple Chat Completions flow to one final-answer request" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "simple"

    client
      .expects(:chat)
      .once
      .with do |args|
        expect(args[:parameters]).not_to have_key(:logprobs)
        true
      end
      .returns(completion_response.call("Initial answer"))

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Initial answer")
    expect(response[:inner_thoughts]).to be_empty
  end

  it "reviews and revises a Chat Completions answer" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "verify_and_revise"
    requests = []

    client
      .expects(:chat)
      .times(3)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        completion_response.call("The answer is five."),
        completion_response.call("REVISE: The arithmetic is incorrect."),
        completion_response.call("The answer is four."),
      )

    response = rag.get_response([{ role: "user", content: "What is 2 + 2?" }], opts)

    expect(response[:reply]).to eq("The answer is four.")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "verify_and_revise"),
        {
          type: "advanced_local_reasoning_review",
          content: "REVISE: The arithmetic is incorrect.",
        },
        advanced_outcome.call("revision_adopted"),
      ],
    )
    expect(requests.second[:max_completion_tokens]).to eq(96)
    expect(requests.second).to include(tool_choice: "none")
    expect(requests.second[:tools]).to be_present
    expect(requests.third).to include(tool_choice: "none")
    expect(requests.third[:tools]).to be_present
  end

  it "records when a review passes and retains the first answer" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "verify_and_revise"
    client
      .expects(:chat)
      .twice
      .returns(completion_response.call("Initial answer"), completion_response.call("PASS"))

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Initial answer")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "verify_and_revise"),
        { type: "advanced_local_reasoning_review", content: "PASS" },
        advanced_outcome.call("review_passed"),
      ],
    )
  end

  it "generates two Chat Completions answers and returns the judge's selection" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "best_of_two"
    requests = []

    client
      .expects(:chat)
      .times(3)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        completion_response.call("Candidate A"),
        completion_response.call("Candidate B"),
        completion_response.call("B"),
      )

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Candidate B")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "best_of_two"),
        {
          type: "advanced_local_reasoning_selection",
          content:
            I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.selection", candidate: "B"),
        },
      ],
    )
    expect(requests.second).to include(tool_choice: "none")
    expect(requests.second[:tools]).to be_present
    expect(requests.third[:max_completion_tokens]).to eq(8)
    expect(requests.third[:messages].last[:content]).to include(
      JSON.generate(A: "Candidate A", B: "Candidate B"),
    )
  end

  it "records when the pairwise judge does not produce a usable selection" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "best_of_two"
    client
      .expects(:chat)
      .times(3)
      .returns(
        completion_response.call("Candidate A"),
        completion_response.call("Candidate B"),
        completion_response.call("Neither"),
      )

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Candidate A")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "best_of_two"),
        advanced_outcome.call("judge_unusable"),
      ],
    )
  end

  it "records when advanced local reasoning fails and retains the first answer" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "best_of_two"
    client
      .expects(:chat)
      .twice
      .returns(completion_response.call("Initial answer"))
      .then
      .raises(RuntimeError, "provider failed")

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Initial answer")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "best_of_two"),
        advanced_outcome.call("strategy_failed", strategy: "best_of_two"),
      ],
    )
  end

  it "accepts a confident uncertainty-guided Chat Completions answer without escalation" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "uncertainty_guided"
    SiteSetting.chatbot_advanced_local_reasoning_min_confidence = 50

    client
      .expects(:chat)
      .once
      .with do |args|
        expect(args[:parameters][:logprobs]).to eq(true)
        true
      end
      .returns(
        completion_response.call(
          "Confident answer",
          logprobs: [{ "token" => "Confident", "logprob" => -0.1 }],
        ),
      )

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Confident answer")
    expect(response[:inner_thoughts].last[:content]).to include("90.5%")
  end

  it "compares a second answer when uncertainty confidence is below the threshold" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "uncertainty_guided"
    requests = []

    client
      .expects(:chat)
      .times(3)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        completion_response.call(
          "Candidate A",
          logprobs: [{ "token" => "Candidate", "logprob" => -2.0 }],
        ),
        completion_response.call("Candidate B"),
        completion_response.call("A"),
      )

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Candidate A")
    expect(requests.first[:logprobs]).to eq(true)
    expect(requests.second).not_to have_key(:logprobs)
    expect(requests.third).not_to have_key(:logprobs)
  end

  it "retries without logprobs when a Chat Completions provider rejects them" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "uncertainty_guided"
    error = RuntimeError.new("unsupported parameter")
    error.stubs(:response).returns(
      status: 400,
      body: {
        "error" => {
          "message" => "Unsupported parameter: logprobs",
        },
      },
    )

    client
      .expects(:chat)
      .times(4)
      .raises(error)
      .then
      .returns(completion_response.call("Candidate A"))
      .then
      .returns(completion_response.call("Candidate B"))
      .then
      .returns(completion_response.call("A"))

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Candidate A")
  end

  it "does not exceed the iteration limit for optional advanced reasoning" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "best_of_two"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 2
    client.expects(:chat).once.returns(completion_response.call("Initial answer"))

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Initial answer")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "best_of_two"),
        advanced_outcome.call("comparison_skipped_iteration_limit"),
      ],
    )
  end

  it "does not claim an uncertainty comparison when the iteration limit prevents one" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "uncertainty_guided"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 2
    client
      .expects(:chat)
      .once
      .returns(
        completion_response.call(
          "Initial answer",
          logprobs: [{ "token" => "Initial", "logprob" => -2.0 }],
        ),
      )

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Initial answer")
    expect(response[:inner_thoughts]).to eq(
      [
        advanced_outcome.call("strategy_started", strategy: "uncertainty_guided"),
        {
          type: "advanced_local_reasoning_confidence",
          content:
            I18n.t(
              "chatbot.prompt.system.rag.advanced_local_reasoning.confidence",
              confidence: "13.5%",
              decision:
                I18n.t(
                  "chatbot.prompt.system.rag.advanced_local_reasoning.confidence_not_accepted",
                ),
            ),
        },
        advanced_outcome.call("comparison_skipped_iteration_limit"),
      ],
    )
  end

  it "does not apply advanced local reasoning to the Responses API" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "best_of_two"
    client.expects(:chat).never
    responses_api
      .expects(:create)
      .once
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "Reasoning answer" }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Answer this" }], opts)

    expect(response[:reply]).to eq("Reasoning answer")
  end

  it "executes tools only on the shared path before comparing answers" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_advanced_local_reasoning = "best_of_two"
    ::DiscourseChatbot::Tools::Calculator
      .any_instance
      .expects(:process)
      .once
      .returns({ answer: "4", token_usage: 0 })
    requests = []

    client
      .expects(:chat)
      .times(4)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "choices" => [
            {
              "finish_reason" => "tool_calls",
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_1",
                    "type" => "function",
                    "function" => {
                      "name" => "calculate",
                      "arguments" => "{\"input\":\"2 + 2\"}",
                    },
                  },
                ],
              },
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        completion_response.call("Candidate A"),
        completion_response.call("Candidate B"),
        completion_response.call("B"),
      )

    response = rag.get_response([{ role: "user", content: "What is 2 + 2?" }], opts)

    expect(response[:reply]).to eq("Candidate B")
    expect(requests.first).to have_key(:tools)
    expect(requests.second).to have_key(:tools)
    expect(requests.third).to include(tool_choice: "none")
    expect(requests.third[:tools]).to be_present
    expect(requests.fourth).to include(tool_choice: "none")
    expect(requests.fourth[:tools]).to be_present
    expect(response[:inner_thoughts]).to eq(
      [
        {
          role: "assistant",
          content: "",
          tool_calls: [
            {
              id: "call_1",
              type: "function",
              function: {
                name: "calculate",
                arguments: "{\"input\":\"2 + 2\"}",
              },
            },
          ],
        },
        { role: "tool", tool_call_id: "call_1", content: "4" },
        advanced_outcome.call("strategy_started", strategy: "best_of_two"),
        {
          type: "advanced_local_reasoning_selection",
          content:
            I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.selection", candidate: "B"),
        },
      ],
    )
  end

  it "returns partial Chat Completions text after reaching the completion budget" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    client
      .expects(:chat)
      .with do |args|
        expect(args[:parameters][:max_completion_tokens]).to eq(200)
        true
      end
      .returns(
        {
          "choices" => [
            { "finish_reason" => "length", "message" => { "content" => "Partial completion" } },
          ],
          "usage" => {
            "total_tokens" => 200,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Write a long answer" }], opts)

    expect(response[:reply]).to eq("Partial completion")
  end

  it "rejects truncated Chat Completions tool calls" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    client
      .expects(:chat)
      .once
      .returns(
        {
          "choices" => [
            {
              "finish_reason" => "length",
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_1",
                    "type" => "function",
                    "function" => {
                      "name" => "calculate",
                      "arguments" => "{\"input\":",
                    },
                  },
                ],
              },
            },
          ],
          "usage" => {
            "total_tokens" => 200,
          },
        },
      )

    expect do
      rag.get_response([{ role: "user", content: "Calculate something" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::Bot::TokenBudgetError,
      "OpenAI response reached its token limit before producing usable content",
    )
  end

  it "can omit reasoning summaries for compatible responses endpoints" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_open_ai_include_reasoning_summaries = false

    responses_api
      .expects(:create)
      .with do |args|
        expect(args[:parameters][:reasoning]).to eq(
          { effort: SiteSetting.chatbot_open_ai_model_reasoning_level },
        )
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "Hello back" }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.create_chat_completion([{ role: "user", content: "Hello" }], false, 1)

    expect(response.dig("choices", 0, "message", "content")).to eq("Hello back")
  end

  it "preserves a rejected response while asking the responses api to repair its URLs" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_url_integrity_check = true
    SiteSetting.chatbot_embeddings_enabled = true
    ::DiscourseChatbot::Tools::ForumSearch
      .any_instance
      .stubs(:process)
      .returns(
        {
          answer: {
            result: "No matching forum posts were found.",
            post_ids_found: [],
            topic_ids_found: [],
            non_post_urls_found: [],
          },
          token_usage: 0,
        },
      )
    invalid_message = {
      "id" => "msg_1",
      "type" => "message",
      "role" => "assistant",
      "content" => [
        { "type" => "output_text", "text" => "See https://unsupported.example for details." },
      ],
    }
    requests = []

    responses_api
      .expects(:create)
      .times(3)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "local_forum_search",
              "arguments" => "{\"query\":\"details\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [invalid_message],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "The answer is 4." }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "What is 2 + 2?" }], opts)

    expect(response[:reply]).to eq("The answer is 4.")
    expect(requests.third[:input].last(2)).to eq(
      [
        invalid_message.deep_symbolize_keys,
        {
          role: "developer",
          content: [{ type: "input_text", text: I18n.t("chatbot.prompt.system.rag.illegal_urls") }],
        },
      ],
    )
  end

  it "does not validate URLs after a tool without trusted URL provenance" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_url_integrity_check = true
    unsupported_url = "https://unsupported.example"

    responses_api
      .expects(:create)
      .times(2)
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "calculate",
              "arguments" => "{\"input\":\"2 + 2\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => unsupported_url }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "What is 2 + 2?" }], opts)

    expect(response[:reply]).to eq(unsupported_url)
  end

  it "collects trusted URL provenance from tools that return URLs" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_url_integrity_check = true
    wikipedia_url = "https://en.wikipedia.org/wiki/Discourse"
    ::DiscourseChatbot::Tools::Wikipedia
      .any_instance
      .stubs(:process)
      .returns({ answer: "Discourse is described at #{wikipedia_url}", token_usage: 0 })

    responses_api
      .expects(:create)
      .times(3)
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "wikipedia",
              "arguments" => "{\"query\":\"Discourse\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => "https://unsupported.example" }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [{ "type" => "output_text", "text" => wikipedia_url }],
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "What is Discourse?" }], opts)

    expect(response[:reply]).to eq(wikipedia_url)
  end

  it "validates partial responses after collecting trusted URL provenance" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_url_integrity_check = true
    SiteSetting.chatbot_embeddings_enabled = true
    ::DiscourseChatbot::Tools::ForumSearch
      .any_instance
      .stubs(:process)
      .returns(
        {
          answer: {
            result: "No matching forum posts were found.",
            post_ids_found: [],
            topic_ids_found: [],
            non_post_urls_found: [],
          },
          token_usage: 0,
        },
      )
    requests = []

    client
      .expects(:chat)
      .times(3)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(
        {
          "choices" => [
            {
              "finish_reason" => "tool_calls",
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_1",
                    "type" => "function",
                    "function" => {
                      "name" => "local_forum_search",
                      "arguments" => "{\"query\":\"details\"}",
                    },
                  },
                ],
              },
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
        {
          "choices" => [
            {
              "finish_reason" => "length",
              "message" => {
                "content" => "Partial answer with https://unsupported.example",
              },
            },
          ],
          "usage" => {
            "total_tokens" => 200,
          },
        },
        {
          "choices" => [
            {
              "finish_reason" => "stop",
              "message" => {
                "content" => "Partial answer without the unsupported link.",
              },
            },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    response = rag.get_response([{ role: "user", content: "Find details" }], opts)

    expect(response[:reply]).to eq("Partial answer without the unsupported link.")
    expect(requests.third[:messages].last).to eq(
      { role: "developer", content: I18n.t("chatbot.prompt.system.rag.illegal_urls") },
    )
  end

  it "disables tools on the final responses api iteration" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 3
    requests = []
    api_responses =
      (SiteSetting.chatbot_chain_of_thought_max_iterations - 1).times.map do |index|
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_#{index}",
              "name" => "calculate",
              "arguments" => "{\"input\":\"2 + 2\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 1,
          },
        }
      end
    api_responses << {
      "status" => "completed",
      "output" => [
        {
          "type" => "message",
          "content" => [{ "type" => "output_text", "text" => "The answer is 4." }],
        },
      ],
      "usage" => {
        "total_tokens" => 1,
      },
    }

    responses_api
      .expects(:create)
      .times(SiteSetting.chatbot_chain_of_thought_max_iterations)
      .with do |args|
        requests << args[:parameters]
        true
      end
      .returns(*api_responses)

    response = rag.get_response([{ role: "user", content: "Keep calculating" }], opts)

    expect(response[:reply]).to eq("The answer is 4.")
    expect(requests.first).to have_key(:tools)
    expect(requests.last).to include(tool_choice: "none")
    expect(requests.last[:tools]).to eq(requests.first[:tools])
  end

  it "raises a non-retryable error after exhausting response iterations" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_chain_of_thought_max_iterations = 2
    reasoning_only_response = {
      "status" => "completed",
      "output" => [{ "type" => "reasoning", "summary" => [] }],
      "usage" => {
        "total_tokens" => 1,
      },
    }
    responses_api
      .expects(:create)
      .times(SiteSetting.chatbot_chain_of_thought_max_iterations)
      .returns(
        *Array.new(SiteSetting.chatbot_chain_of_thought_max_iterations, reasoning_only_response),
      )

    expect do
      rag.get_response([{ role: "user", content: "Keep reasoning" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::Bot::ChainLimitError,
      "Chatbot response exceeded the maximum number of iterations",
    )
  end

  it "raises a non-retryable error after exceeding the configured tool-call limit" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_chain_of_thought_max_tool_calls = 1
    responses_api.expects(:create).returns(
      {
        "status" => "completed",
        "output" => [
          {
            "type" => "function_call",
            "call_id" => "call_1",
            "name" => "calculate",
            "arguments" => "{\"input\":\"2 + 2\"}",
          },
          {
            "type" => "function_call",
            "call_id" => "call_2",
            "name" => "calculate",
            "arguments" => "{\"input\":\"3 + 3\"}",
          },
        ],
        "usage" => {
          "total_tokens" => 2,
        },
      },
    )

    expect do
      rag.get_response([{ role: "user", content: "Calculate twice" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::Bot::ChainLimitError,
      "Chatbot response exceeded the maximum number of tool calls",
    )
  end

  it "raises a non-retryable error when URL repairs are disabled" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_url_integrity_check = true
    SiteSetting.chatbot_chain_of_thought_max_url_repair_attempts = 0
    SiteSetting.chatbot_embeddings_enabled = true
    ::DiscourseChatbot::Tools::ForumSearch
      .any_instance
      .stubs(:process)
      .returns(
        {
          answer: {
            result: "No matching forum posts were found.",
            post_ids_found: [],
            topic_ids_found: [],
            non_post_urls_found: [],
          },
          token_usage: 0,
        },
      )
    responses_api
      .expects(:create)
      .times(2)
      .returns(
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "function_call",
              "call_id" => "call_1",
              "name" => "local_forum_search",
              "arguments" => "{\"query\":\"details\"}",
            },
          ],
          "usage" => {
            "total_tokens" => 1,
          },
        },
        {
          "status" => "completed",
          "output" => [
            {
              "type" => "message",
              "content" => [
                {
                  "type" => "output_text",
                  "text" => "See https://unsupported.example for details.",
                },
              ],
            },
          ],
          "usage" => {
            "total_tokens" => 1,
          },
        },
      )

    expect do
      rag.get_response([{ role: "user", content: "Find details" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::Bot::ChainLimitError,
      "Chatbot response repeatedly contained unsupported URLs",
    )
  end
end

describe ::DiscourseChatbot::Bot, "#get_system_message_suffix" do
  fab!(:user)
  let(:opts) { { user_id: user.id } }
  let(:rag) { described_class.new(opts) }

  before { SiteSetting.discourse_local_dates_enabled = false }

  it "returns custom field prompts when enabled" do
    SiteSetting.chatbot_include_custom_field_prompts = true

    ::UserCustomField.create!(
      user_id: user.id,
      name: "chatbot_additional_prompt",
      value: "Bring a laptop.",
    )

    expect(rag.get_system_message_suffix(opts)).to eq("Bring a laptop.")
  end

  it "returns empty when custom field prompts are disabled" do
    SiteSetting.chatbot_include_custom_field_prompts = false

    ::UserCustomField.create!(
      user_id: user.id,
      name: "chatbot_additional_prompt",
      value: "Bring a laptop.",
    )

    expect(rag.get_system_message_suffix(opts)).to eq("")
  end
end

describe ::DiscourseChatbot::Bot, "#get_system_message_suffix via api", type: :request do
  fab!(:user)
  fab!(:admin)
  let(:api_key) { Fabricate(:api_key, user: admin) }
  let(:opts) { { user_id: user.id } }
  let(:rag) { described_class.new(opts) }

  before do
    SiteSetting.discourse_local_dates_enabled = false
    SiteSetting.chatbot_include_custom_field_prompts = true
  end

  after do
    DiscoursePluginRegistry.reset_register!(:self_editable_user_custom_fields)
    DiscoursePluginRegistry.reset_register!(:staff_editable_user_custom_fields)
  end

  it "reads custom field prompts updated via api key" do
    put "/u/#{user.username}.json",
        params: {
          custom_fields: {
            chatbot_additional_prompt: "Bring a laptop.",
          },
        },
        headers: {
          HTTP_API_KEY: api_key.key,
        }

    expect(response.status).to eq(200)
    expect(rag.get_system_message_suffix(opts)).to eq("Bring a laptop.")
  end
end

describe ::DiscourseChatbot::Bot, "#merge_tools" do
  fab!(:user)

  let(:extension_tool_classes) { [] }

  before { ::DiscourseChatbot::Tool.stubs(:descendants).returns(extension_tool_classes) }

  let(:enable_tools) do
    ->(*tool_names) { SiteSetting.chatbot_tools_low_trust = tool_names.join("|") }
  end

  let(:build_extension_tool) do
    lambda do |name, availability: nil, &initializer|
      tool_class =
        Class.new(::DiscourseChatbot::Tool) do
          define_singleton_method(:available?) { |opts| availability.call(opts) } if availability
          define_method(:name) { name }
          define_method(:description) { "An extension tool used by this spec" }
          define_method(:parameters) { [] }
          define_method(:required) { [] }
          define_method(:initialize, &initializer) if initializer
        end
      extension_tool_classes << tool_class
      tool_class
    end
  end

  it "includes the default high-trust tools" do
    rag = described_class.new({ trust_level: "high" })
    tool_mapping = rag.instance_variable_get(:@tool_mapping)

    expect(tool_mapping).to have_key("wikipedia")
  end

  it "orders extension tools by name" do
    enable_tools.call
    build_extension_tool.call("zeta")
    build_extension_tool.call("alpha")

    tool_definitions = described_class.new({}).instance_variable_get(:@tool_definitions)

    expect(tool_definitions.map { |tool| tool["name"] }).to eq(%w[alpha zeta])
  end

  it "excludes tools that are not selected" do
    rag = described_class.new({})
    tool_mapping = rag.instance_variable_get(:@tool_mapping)

    expect(tool_mapping).not_to have_key("wikipedia")
  end

  it "does not send a tools parameter when no built-in or extension tools are available" do
    SiteSetting.chatbot_tools_low_trust = ""
    client = mock
    OpenAI::Client.stubs(:new).returns(client)
    bot = described_class.new({})

    client
      .expects(:chat)
      .with { |args| !args[:parameters].key?(:tools) }
      .returns(
        {
          "choices" => [{ "finish_reason" => "stop", "message" => { "content" => "Hello" } }],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    expect(bot.get_response([{ role: "user", content: "Hi" }], {})).to include(reply: "Hello")
  end

  it "requires both selection and a configured credential for token-gated tools" do
    enable_tools.call("news")
    without_token = described_class.new({}).instance_variable_get(:@tool_mapping)

    SiteSetting.chatbot_news_api_token = "token"
    with_token = described_class.new({}).instance_variable_get(:@tool_mapping)

    expect(without_token).not_to have_key("news")
    expect(with_token).to have_key("news")
  end

  it "always includes escalate_to_staff even when inside cooldown" do
    enable_tools.call("escalate_to_staff")
    SiteSetting.chatbot_escalate_to_staff_cool_down_period = 1

    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD,
      value: 5.days.ago.utc.to_s,
    )
    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD,
      value: 2.hours.ago.utc.to_s,
    )

    rag =
      described_class.new({ private: true, type: ::DiscourseChatbot::MESSAGE, user_id: user.id })
    tool_mapping = rag.instance_variable_get(:@tool_mapping)

    expect(tool_mapping).to have_key("escalate_to_staff")
  end

  it "includes escalate_to_staff even when latest cooldown date is invalid" do
    enable_tools.call("escalate_to_staff")
    SiteSetting.chatbot_escalate_to_staff_cool_down_period = 1

    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD,
      value: 2.hours.ago.utc.to_s,
    )
    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD,
      value: "not-a-time",
    )

    rag =
      described_class.new({ private: true, type: ::DiscourseChatbot::MESSAGE, user_id: user.id })
    tool_mapping = rag.instance_variable_get(:@tool_mapping)

    expect(tool_mapping).to have_key("escalate_to_staff")
  end

  %w[gpt-image-1 gpt-image-1-mini gpt-image-1.5 gpt-image-2].each do |model_name|
    it "includes paint_edit_picture for #{model_name}" do
      enable_tools.call("paint_edit_picture")
      SiteSetting.chatbot_support_picture_creation_model = model_name

      rag = described_class.new({})
      tool_mapping = rag.instance_variable_get(:@tool_mapping)

      expect(tool_mapping).to have_key("paint_edit_picture")
    end
  end

  it "does not include paint_edit_picture for dall-e-3" do
    enable_tools.call("paint_edit_picture")
    SiteSetting.chatbot_support_picture_creation_model = "dall-e-3"

    rag = described_class.new({})
    tool_mapping = rag.instance_variable_get(:@tool_mapping)

    expect(tool_mapping).not_to have_key("paint_edit_picture")
  end

  it "discovers external tools and honors their availability" do
    extension_name = "conditional_extension"
    build_extension_tool.call(
      extension_name,
      availability: ->(opts) { opts[:enable_test_extension] },
    )

    enabled_mapping =
      described_class.new({ enable_test_extension: true }).instance_variable_get(:@tool_mapping)
    disabled_mapping = described_class.new({}).instance_variable_get(:@tool_mapping)

    expect(enabled_mapping).to have_key(extension_name)
    expect(disabled_mapping).not_to have_key(extension_name)
    expect(::DiscourseChatbot::Tool.choices).not_to include(extension_name)
  end

  it "isolates errors raised by individual external tools" do
    build_extension_tool.call(
      "unavailable_extension",
      availability: ->(_opts) { raise "availability failed" },
    )
    build_extension_tool.call("invalid_extension") { |_required_argument| }
    build_extension_tool.call("healthy_extension")

    tool_mapping = described_class.new({}).instance_variable_get(:@tool_mapping)

    expect(tool_mapping).to have_key("healthy_extension")
  end
end

describe ::DiscourseChatbot, ".latest_chatbot_escalation_topic_id" do
  fab!(:user)

  it "returns the most recent parseable topic id when duplicate rows exist" do
    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_TOPIC_ID_CUSTOM_FIELD,
      value: "111",
    )
    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_TOPIC_ID_CUSTOM_FIELD,
      value: "not-a-topic-id",
    )

    expect(::DiscourseChatbot.latest_chatbot_escalation_topic_id(user.id)).to eq(111)
  end
end

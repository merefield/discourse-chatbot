# frozen_string_literal: true
require_relative "../../plugin_helper"

RSpec.configure do |config|
  config.prepend_before(:suite) do
    User.find_by(username: "Chatbot") || Fabricate(:user, username: "Chatbot")
  end
end

describe ::DiscourseChatbot::OpenAiBotRag do
  let(:opts) { {} }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }
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
    OpenAI::Client.stubs(:new).returns(client)
    client.stubs(:responses).returns(responses_api)
  end
  let(:post_ids_found_2) { [post_1.id] }
  let(:res) do
    "the value is 90 and I found that informaiton in [this topic](https://discourse.example.com/t/slug/112)"
  end
  let(:res_2) do
    "the value is 99 and I found that informaiton in [this post](https://#{Discourse.current_hostname}/t/slug/112/2)"
  end

  it "calls function on returning a function request from LLN" do
    DateTime.expects(:current).returns("2023-08-18T10:11:44+00:00")

    query = [{ role: "user", content: "merefield said what is 3 * 23.452432?" }]

    system_entry = {
      role: "developer",
      content:
        "You are a helpful assistant.  You have great tools in the form of functions that give you the power to get newer information. Only use the functions you have been provided with.  The current date and time is 2023-08-18T10:11:44+00:00.  When referring to users by name, include an @ symbol directly in front of their username.  Only respond to the last question, using the prior information as context, if appropriate.",
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

  it "rejects forum URLs on another host" do
    response = "See https://evil.example/t/slug/#{topic_1.id}"

    expect(described_class.new({}).legal_post_urls?(response, [], [topic_1.id])).to eq(false)
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
        "hello https://someplace.com/t/slug/113/2 try looking at https://example.com it's great",
        %w[https://example.com https://otherexample.com],
      ),
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
      "summary" => [
        {
          "type" => "summary_text",
          "text" => "I need to calculate the expression.",
        },
      ],
    }
    final_reasoning_item = {
      "id" => "rs_2",
      "type" => "reasoning",
      "summary" => [
        {
          "type" => "summary_text",
          "text" => "The calculation result is sufficient to answer.",
        },
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
        {
          type: "reasoning_summary",
          content: "The calculation result is sufficient to answer.",
        },
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
        {
          "type" => "summary_text",
          "text" => "I need another step before answering.",
        },
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
      [
        {
          type: "reasoning_summary",
          content: "I need another step before answering.",
        },
      ],
    )
    expect(requests.second[:input].last).to eq(reasoning_item.deep_symbolize_keys)
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
    end.to raise_error(::DiscourseChatbot::OpenAIBotBase::TokenBudgetError)

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
    end.to raise_error(::DiscourseChatbot::OpenAIBotBase::TokenBudgetError)

    expect(rag.inner_thoughts).to eq([{ type: "reasoning_summary", content: summary_text }])
  end

  it "stops a reasoning continuation after reaching the aggregate chain budget" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_open_ai_max_chain_tokens = 5
    responses_api.expects(:create).once.returns(
      {
        "status" => "completed",
        "output" => [
          {
            "type" => "reasoning",
            "summary" => [],
          },
        ],
        "usage" => {
          "total_tokens" => 5,
        },
      },
    )

    expect do
      rag.get_response([{ role: "user", content: "Think this through" }], opts)
    end.to raise_error(
      ::DiscourseChatbot::OpenAIBotBase::TokenBudgetError,
      "OpenAI response exceeded the configured chatbot_open_ai_max_chain_tokens budget",
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
            {
              "finish_reason" => "length",
              "message" => {
                "content" => "Partial completion",
              },
            },
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
    client.expects(:chat).once.returns(
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
      ::DiscourseChatbot::OpenAIBotBase::TokenBudgetError,
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
    ::DiscourseChatbot::ForumSearchFunction.any_instance.stubs(:process).returns(
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
        {
          "type" => "output_text",
          "text" => "See https://unsupported.example for details.",
        },
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
          content: [
            {
              type: "input_text",
              text: I18n.t("chatbot.prompt.system.rag.illegal_urls"),
            },
          ],
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

  it "validates partial responses after collecting trusted URL provenance" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_url_integrity_check = true
    SiteSetting.chatbot_embeddings_enabled = true
    ::DiscourseChatbot::ForumSearchFunction.any_instance.stubs(:process).returns(
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
      {
        role: "developer",
        content: I18n.t("chatbot.prompt.system.rag.illegal_urls"),
      },
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
    expect(requests.last).not_to have_key(:tools)
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
      ::DiscourseChatbot::OpenAIBotBase::ChainLimitError,
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
      ::DiscourseChatbot::OpenAIBotBase::ChainLimitError,
      "Chatbot response exceeded the maximum number of tool calls",
    )
  end

  it "raises a non-retryable error when URL repairs are disabled" do
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-5.4-mini"
    SiteSetting.chatbot_url_integrity_check = true
    SiteSetting.chatbot_chain_of_thought_max_url_repair_attempts = 0
    SiteSetting.chatbot_embeddings_enabled = true
    ::DiscourseChatbot::ForumSearchFunction.any_instance.stubs(:process).returns(
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
      ::DiscourseChatbot::OpenAIBotBase::ChainLimitError,
      "Chatbot response repeatedly contained unsupported URLs",
    )
  end
end

describe ::DiscourseChatbot::OpenAiBotRag, "#get_system_message_suffix" do
  fab!(:user)
  let(:opts) { { user_id: user.id } }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }

  before { SiteSetting.discourse_local_dates_enabled = false }

  it "returns custom field prompts when enabled" do
    SiteSetting.chatbot_include_custom_field_prompts = true
    SiteSetting.chatbot_user_fields_collection = false

    ::UserCustomField.create!(
      user_id: user.id,
      name: "chatbot_additional_prompt",
      value: "Bring a laptop.",
    )

    expect(rag.get_system_message_suffix(opts)).to eq("Bring a laptop.")
  end

  it "returns empty when custom field prompts are disabled" do
    SiteSetting.chatbot_include_custom_field_prompts = false
    SiteSetting.chatbot_user_fields_collection = false

    ::UserCustomField.create!(
      user_id: user.id,
      name: "chatbot_additional_prompt",
      value: "Bring a laptop.",
    )

    expect(rag.get_system_message_suffix(opts)).to eq("")
  end
end

describe ::DiscourseChatbot::OpenAiBotRag, "#get_system_message_suffix via api", type: :request do
  fab!(:user)
  fab!(:admin)
  let(:api_key) { Fabricate(:api_key, user: admin) }
  let(:opts) { { user_id: user.id } }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }

  before do
    SiteSetting.discourse_local_dates_enabled = false
    SiteSetting.chatbot_include_custom_field_prompts = true
    SiteSetting.chatbot_user_fields_collection = false
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

describe ::DiscourseChatbot::OpenAiBotRag, "#merge_functions" do
  fab!(:user)

  it "includes wikipedia by default" do
    rag = described_class.new({})
    func_mapping = rag.instance_variable_get(:@func_mapping)

    expect(func_mapping).to have_key("wikipedia")
  end

  it "excludes wikipedia when disabled" do
    SiteSetting.chatbot_wikipedia_function = false

    rag = described_class.new({})
    func_mapping = rag.instance_variable_get(:@func_mapping)

    expect(func_mapping).not_to have_key("wikipedia")
  end

  it "always includes escalate_to_staff even when inside cooldown" do
    SiteSetting.chatbot_escalate_to_staff_function = true
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
    func_mapping = rag.instance_variable_get(:@func_mapping)

    expect(func_mapping).to have_key("escalate_to_staff")
  end

  it "includes escalate_to_staff even when latest cooldown date is invalid" do
    SiteSetting.chatbot_escalate_to_staff_function = true
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
    func_mapping = rag.instance_variable_get(:@func_mapping)

    expect(func_mapping).to have_key("escalate_to_staff")
  end

  %w[gpt-image-1 gpt-image-1-mini gpt-image-1.5 gpt-image-2].each do |model_name|
    it "includes paint_edit_picture for #{model_name}" do
      SiteSetting.chatbot_support_picture_creation = true
      SiteSetting.chatbot_support_picture_creation_model = model_name

      rag = described_class.new({})
      func_mapping = rag.instance_variable_get(:@func_mapping)

      expect(func_mapping).to have_key("paint_edit_picture")
    end
  end

  it "does not include paint_edit_picture for dall-e-3" do
    SiteSetting.chatbot_support_picture_creation = true
    SiteSetting.chatbot_support_picture_creation_model = "dall-e-3"

    rag = described_class.new({})
    func_mapping = rag.instance_variable_get(:@func_mapping)

    expect(func_mapping).not_to have_key("paint_edit_picture")
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

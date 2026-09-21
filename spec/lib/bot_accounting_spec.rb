# frozen_string_literal: true

require_relative "../plugin_helper"

describe DiscourseChatbot::Bot do
  fab!(:user)
  fab!(:bot_user, :user)
  fab!(:post) { Fabricate(:post, user: user) }

  let(:client) { mock }
  let(:opts) do
    {
      type: DiscourseChatbot::POST,
      user_id: user.id,
      bot_user_id: bot_user.id,
      reply_to_message_or_post_id: post.id,
      original_post_number: post.post_number,
      category_id: post.topic.category_id,
    }
  end
  let(:search_response) do
    {
      "choices" => [
        {
          "finish_reason" => "tool_calls",
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              {
                "id" => "call_search",
                "type" => "function",
                "function" => {
                  "name" => "web_search",
                  "arguments" => '{"query":"test"}',
                },
              },
            ],
          },
        },
      ],
      "usage" => {
        "total_tokens" => 100,
      },
    }
  end
  let(:final_response) do
    {
      "choices" => [
        { "finish_reason" => "stop", "message" => { "content" => "Here is the answer." } },
      ],
      "usage" => {
        "total_tokens" => 50,
      },
    }
  end

  before do
    SiteSetting.chatbot_tools_low_trust = "web_search"
    SiteSetting.chatbot_serp_api_key = ""
    SiteSetting.chatbot_jina_api_token = "test-key"
    SiteSetting.chatbot_jina_api_token_cost_multiplier = 10_000
    SiteSetting.chatbot_open_ai_max_chain_tokens = 100_000
    SiteSetting.chatbot_open_ai_model_low_trust = "gpt-4.1-mini"
    SiteSetting.chatbot_quota_basis = "tokens"
    OpenAI::Client.stubs(:new).returns(client)
    stub_request(:get, "https://s.jina.ai/test").to_return(body: "A short search result.")
  end

  it "finishes after a large tool charge and deducts both model usage and tool costs" do
    quota =
      UserCustomField.create!(
        user_id: user.id,
        name: DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
        value: "500000",
      )
    client.expects(:chat).twice.returns(search_response, final_response)

    response = described_class.new(opts).ask(opts)

    expect(response[:reply]).to eq("Here is the answer.")
    expect(response[:usage_statistics]).to include(
      total_tokens: 150,
      tool_quota_tokens: 220_000,
      quota_tokens: 220_150,
      chain_tokens: 150,
    )
    expect(quota.reload.value).to eq("279850")
  end

  it "still charges one query when using query-based quotas" do
    SiteSetting.chatbot_quota_basis = "queries"
    quota =
      UserCustomField.create!(
        user_id: user.id,
        name: DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
        value: "10",
      )
    client.expects(:chat).twice.returns(search_response, final_response)

    described_class.new(opts).ask(opts)

    expect(quota.reload.value).to eq("9")
  end

  it "stops at the actual model budget and charges consumed usage on failure" do
    SiteSetting.chatbot_open_ai_max_chain_tokens = 100
    quota =
      UserCustomField.create!(
        user_id: user.id,
        name: DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
        value: "500000",
      )
    client.expects(:chat).once.returns(search_response)

    expect { described_class.new(opts).ask(opts) }.to raise_error(described_class::TokenBudgetError)
    expect(quota.reload.value).to eq("499900")
    expect(WebMock).not_to have_requested(:get, "https://s.jina.ai/test")
  end
  it "counts actual vision model usage toward the chain budget" do
    SiteSetting.chatbot_tools_low_trust = "vision"
    SiteSetting.chatbot_open_ai_max_chain_tokens = 200
    upload = Fabricate(:upload)
    post.update!(image_upload_id: upload.id, post_number: 2, reply_to_post_number: 1)
    tool_response = search_response.deep_dup
    tool_response["choices"][0]["message"]["tool_calls"][0]["function"] = {
      "name" => "vision",
      "arguments" => '{"query":"Describe this image"}',
    }
    client
      .expects(:chat)
      .twice
      .returns(
        tool_response,
        {
          "choices" => [{ "message" => { "content" => "A landscape." } }],
          "usage" => {
            "total_tokens" => 100,
          },
        },
      )
    bot = described_class.new(opts)

    expect {
      bot.get_response([{ role: "user", content: "Describe this image" }], opts)
    }.to raise_error(described_class::TokenBudgetError)
    expect(bot.usage_statistics).to include(
      total_tokens: 100,
      tool_quota_tokens: 100,
      quota_tokens: 200,
      chain_tokens: 200,
    )
  end

  it "retains the tool charge when the subsequent model request fails" do
    quota =
      UserCustomField.create!(
        user_id: user.id,
        name: DiscourseChatbot::CHATBOT_REMAINING_QUOTA_TOKENS_CUSTOM_FIELD,
        value: "500000",
      )
    client
      .expects(:chat)
      .twice
      .returns(search_response)
      .then
      .raises(StandardError, "provider unavailable")

    expect { described_class.new(opts).ask(opts) }.to raise_error(
      StandardError,
      "provider unavailable",
    )
    expect(quota.reload.value).to eq("279900")
  end
end

# frozen_string_literal: true

RSpec.describe Jobs::ChatbotReply do
  fab!(:requester, :user)
  fab!(:bot_user, :user)
  fab!(:pm_topic) { Fabricate(:private_message_topic, user: requester, recipient: bot_user) }

  before do
    enable_current_plugin

    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_permitted_in_private_messages = true
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_private_message_auto_title = false
  end

  it "replies immediately when the token budget is reached" do
    SiteSetting.chatbot_include_inner_thoughts_in_private_messages = true
    post = PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::Post::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"
    summary_text = "I used the available budget to investigate the question."

    ::DiscourseChatbot::Bot
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::Bot::TokenBudgetError, "budget reached")
    ::DiscourseChatbot::Bot
      .any_instance
      .stubs(:inner_thoughts)
      .returns([{ type: "reasoning_summary", content: summary_text }])

    described_class.new.execute(opts)

    replies = pm_topic.posts.order(:post_number).last(2)
    expect(replies.first.raw).to include(summary_text)
    expect(replies.last.raw).to eq(I18n.t("chatbot.errors.token_budget"))
  end

  it "replies immediately when a chain limit is reached" do
    post = PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::Post::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    ::DiscourseChatbot::Bot
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::Bot::ChainLimitError, "iteration limit reached")

    described_class.new.execute(opts)

    expect(pm_topic.posts.order(:post_number).last.raw).to eq(I18n.t("chatbot.errors.chain_limit"))
  end

  it "retries provider errors" do
    post = PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::Post::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    ::DiscourseChatbot::Bot
      .any_instance
      .stubs(:ask)
      .raises(::DiscourseChatbot::Bot::ResponsesApiError, "provider failed")

    expect { described_class.new.execute(opts) }.to raise_error(
      ::DiscourseChatbot::Bot::ResponsesApiError,
      "provider failed",
    )
  end

  it "returns a blocked-question response with RAG inner thoughts and no quota or title cost" do
    SiteSetting.chatbot_blocked_questions_enabled = true
    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Politics", example_question: "Who should I vote for in the next election?" },
    ].to_json
    SiteSetting.chatbot_private_message_auto_title = true
    SiteSetting.chatbot_include_inner_thoughts_in_private_messages = true

    client = mock
    client
      .expects(:embeddings)
      .times(2)
      .returns(embedding_response([1.0, 0.0]), embedding_response([0.99, 0.01]))
    OpenAI::Client.stubs(:new).returns(client)

    original_title = pm_topic.title
    quota =
      UserCustomField.create!(
        user_id: requester.id,
        name: ::DiscourseChatbot::CHATBOT_REMAINING_QUOTA_QUERIES_CUSTOM_FIELD,
        value: "10",
      )
    post =
      PostCreator.create!(
        requester,
        topic_id: pm_topic.id,
        raw: "Who should I vote for, @#{bot_user.username}?",
      )
    opts = ::DiscourseChatbot::Post::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    described_class.new.execute(opts)

    replies = pm_topic.posts.order(:post_number).last(2)
    expect(replies.first.raw).to include(
      '"type": "blocked_question_evaluation"',
      '"outcome": "blocked"',
      '"category": "Politics"',
      '"example_question": "Who should I vote for in the next election?"',
      '"similarity": 0.9999',
      '"threshold": 0.8',
      '"embedding_model": "text-embedding-ada-002"',
    )
    expect(replies.last.raw).to eq(I18n.t("chatbot.errors.blocked_question", category: "Politics"))
    expect(pm_topic.reload.title).to eq(original_title)
    expect(quota.reload.value).to eq("10")
  end

  it "records an insufficient blocked-question match before the RAG response" do
    SiteSetting.chatbot_blocked_questions_enabled = true
    SiteSetting.chatbot_blocked_question_examples = [
      { category: "Politics", example_question: "Who should I vote for in the next election?" },
    ].to_json
    SiteSetting.chatbot_blocked_questions_similarity_threshold = 0.9
    SiteSetting.chatbot_include_inner_thoughts_in_private_messages = true

    client = mock
    client
      .expects(:embeddings)
      .times(2)
      .returns(embedding_response([1.0, 0.0]), embedding_response([0.7, 0.7]))
    OpenAI::Client.stubs(:new).returns(client)
    ::DiscourseChatbot::Bot
      .any_instance
      .expects(:create_chat_completion)
      .with do |messages, _use_tools, _iteration|
        expect(JSON.generate(messages)).not_to include("blocked_question_evaluation")
        true
      end
      .returns(
        {
          "choices" => [
            { "finish_reason" => "stop", "message" => { "content" => "A normal RAG answer" } },
          ],
          "usage" => {
            "total_tokens" => 2,
          },
        },
      )

    post =
      PostCreator.create!(
        requester,
        topic_id: pm_topic.id,
        raw: "Tell me how to bake bread, @#{bot_user.username}",
      )
    opts = ::DiscourseChatbot::Post::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    described_class.new.execute(opts)

    replies = pm_topic.posts.order(:post_number).last(2)
    expect(replies.first.raw).to include(
      '"type": "blocked_question_evaluation"',
      '"outcome": "below_threshold"',
      '"category": "Politics"',
      '"similarity": 0.7071',
      '"threshold": 0.9',
      "Allowed the request to continue",
    )
    expect(replies.last.raw).to eq("A normal RAG answer")
  end

  it "persists usage statistics outside future model context" do
    SiteSetting.chatbot_include_inner_thoughts_in_private_messages = true
    statistics = {
      type: "usage_statistics",
      model: "gpt-5.6",
      input_tokens: 200,
      cached_input_tokens: 150,
      cached_input_percentage: 75.0,
      output_tokens: 40,
      reasoning_tokens: 10,
      total_tokens: 240,
    }
    post = PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")
    opts = ::DiscourseChatbot::Post::PostEvaluation.new.trigger_response(post)
    opts[:trust_level] = "low"

    ::DiscourseChatbot::Bot
      .any_instance
      .stubs(:ask)
      .returns(
        {
          reply: "A measured response",
          inner_thoughts: [],
          usage_statistics: statistics,
          total_tokens: 240,
        },
      )

    described_class.new.execute(opts)

    replies = pm_topic.posts.order(:post_number).last(2)
    audit_post = replies.first
    expect(JSON.parse(audit_post.raw[/```json\n(.*)\n```/m, 1])).to eq(
      [statistics.deep_stringify_keys],
    )
    expect(replies.last.raw).to eq("A measured response")

    follow_up = PostCreator.create!(requester, topic_id: pm_topic.id, raw: "Tell me more")
    prompt =
      ::DiscourseChatbot::Post::PostPromptUtils.create_prompt(
        reply_to_message_or_post_id: follow_up.id,
        original_post_number: follow_up.post_number,
        bot_user_id: bot_user.id,
        category_id: pm_topic.category_id,
      )

    expect(JSON.generate(prompt)).not_to include(audit_post.raw)
  end
end

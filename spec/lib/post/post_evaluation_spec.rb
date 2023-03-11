# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::PostEvaluation do
  let(:topic) { Fabricate(:topic) }
  let(:post_args) { { user: topic.user, topic: topic } }
  let(:bot_user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }

  def post_with_body(body, user = nil)
    args = post_args.merge(raw: body)
    args[:user] = user if user.present?
    Fabricate.build(:post, args)
  end

  before(:each) do
    SiteSetting.chatbot_enabled = true
  end

  it "It does not trigger a bot to respond when the first post doesn't contain an @ mention" do
    SiteSetting.chatbot_bot_user = bot_user.username
    post =
    PostCreator.create!(
      topic.user,
      title: "hello there, how are we all doing?!",
      raw: "hello there!"
    )

    event_evaluation = ::DiscourseChatbot::PostEvaluation.new
    triggered = event_evaluation.on_submission(post)

    expect(triggered).to equal(false)
  end

  it "It does trigger a bot to respond when the first post does contain an @ mention of the bot" do
    SiteSetting.chatbot_bot_user = bot_user.username
    post =
    PostCreator.create!(
      topic.user,
      title: "hello there, how are we all doing?!",
      raw: "hello there @#{bot_user.username}"
    )

    event_evaluation = ::DiscourseChatbot::PostEvaluation.new
    triggered = event_evaluation.on_submission(post)

    expect(triggered).to equal(true)
  end

  it "It does trigger a bot to respond when the topic only contains the first user and the bot and there is no @ mention" do
    SiteSetting.chatbot_bot_user = bot_user.username
    post =
    PostCreator.create!(
      topic.user,
      title: "hello there, how are we all doing?!",
      raw: "hello there @#{bot_user.username}"
    )
    post =
    PostCreator.create!(
      bot_user,
      topic_id: post.topic.id,
      raw: "hello back"
    )
    post =
    PostCreator.create!(
      topic.user,
      topic_id: post.topic.id,
      raw: "hello there again!"
    )

    event_evaluation = ::DiscourseChatbot::PostEvaluation.new
    triggered = event_evaluation.on_submission(post)

    expect(triggered).to equal(true)
  end

  it "It does trigger bot to respond when the topic contains at least two human users and the bot and there is no @ mention" do
    SiteSetting.chatbot_bot_user = bot_user.username
    post =
    PostCreator.create!(
      topic.user,
      title: "hello there everyone!",
      raw: "hello there everyone!"
    )
    post =
    PostCreator.create!(
      other_user,
      topic_id: post.topic.id,
      raw: "hello friend!"
    )
    post =
    PostCreator.create!(
      topic.user,
      topic_id: post.topic.id,
      raw: "hello there @#{bot_user.username}"
    )
    post =
    PostCreator.create!(
      bot_user,
      topic_id: post.topic.id,
      raw: "hello back"
    )
    post =
    PostCreator.create!(
      topic.user,
      topic_id: post.topic.id,
      raw: "hello there again!"
    )

    event_evaluation = ::DiscourseChatbot::PostEvaluation.new
    triggered = event_evaluation.on_submission(post)

    expect(triggered).to equal(false)
  end

end

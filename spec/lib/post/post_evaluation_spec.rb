# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::PostEvaluation do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:category) { Fabricate(:category) }
  let(:auto_category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, user: user, category: category) }
  let(:topic_in_auto_category) { Fabricate(:topic, category: auto_category) }
  let(:post_args) { { user: topic.user, topic: topic } }
  let(:bot_user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:other_user) { Fabricate(:user, refresh_auto_groups: true) }

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

  it "It does trigger a bot to respond when the first post is in a Category included in auto respond Categories" do
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_auto_respond_categories = auto_category.id.to_s

    post =
    PostCreator.create!(
      topic_in_auto_category.user,
      topic_id: topic_in_auto_category.id,
      title: "hello there, how are we all doing?!",
      raw: "hello there!"
    )

    event_evaluation = ::DiscourseChatbot::PostEvaluation.new
    triggered = event_evaluation.on_submission(post)

    expect(triggered).to equal(true)
  end

  it "It does NOT trigger a bot to respond when the first post is in a Category NOT included in auto respond Categories" do
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_auto_respond_categories = auto_category.id.to_s

    post =
    PostCreator.create!(
      topic.user,
      topic_id: topic.id,
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

# frozen_string_literal: true

require_relative "../../plugin_helper"

describe ::Post, "#revise" do
  fab!(:user)
  fab!(:bot_user) { Fabricate(:user, username: "help_bot") }
  fab!(:post) { Fabricate(:post, user: user, raw: "Hello, can someone help me?") }

  before do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_reply_job_time_delay = 0
    Jobs::ChatbotReply.jobs.clear
  end

  it "replies when an edit adds a mention and ignores subsequent grace-period edits" do
    expect(post.revise(user, raw: "Hello @help_bot, can you help me?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs.size).to eq(1)
    expect(Jobs::ChatbotReply.jobs.last["args"].first).to include(
      "reply_to_message_or_post_id" => post.id,
      "bot_user_id" => bot_user.id,
      "user_id" => user.id,
    )

    expect(post.reload.revise(user, raw: "Hello @HELP_BOT, can you help me please?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs.size).to eq(1)
  end

  it "ignores an existing mention when a grace-period edit becomes a new revision" do
    expect(post.revise(user, raw: "Hello @help_bot, can you help me?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs.size).to eq(1)

    expect(
      post.reload.revise(
        user,
        { raw: "Hello @help_bot, can you help me please?" },
        force_new_version: true,
      ),
    ).to eq(true)
    expect(Jobs::ChatbotReply.jobs.size).to eq(1)
  end

  it "replies when an edit fixes a missing at symbol or misspelled username" do
    ["Hello help_bot, can you help?", "Hello @help_bto, can you help?"].each do |raw|
      post.update!(raw: raw)
      Jobs::ChatbotReply.jobs.clear

      expect(post.reload.revise(user, raw: "Hello @help_bot, can you help?")).to eq(true)
      expect(Jobs::ChatbotReply.jobs.size).to eq(1)
    end
  end

  it "ignores an existing mention, a removed mention, and title-only edits" do
    post.update!(raw: "Hello @help_bot, can you help?")

    expect(post.revise(user, raw: "Hello @help_bot, can you help me please?")).to eq(true)
    expect(post.reload.revise(user, title: "An updated topic title")).to eq(true)
    expect(post.reload.revise(user, raw: "Hello everyone, can you help?")).to eq(true)

    expect(Jobs::ChatbotReply.jobs).to be_empty
  end

  it "ignores quoted mentions but replies when a mention moves outside the quote" do
    quoted_raw = "[quote=someone]Hello @help_bot[/quote]\nCan someone help?"
    expect(post.revise(user, raw: quoted_raw)).to eq(true)
    expect(Jobs::ChatbotReply.jobs).to be_empty

    expect(post.reload.revise(user, raw: "#{quoted_raw}\nHello @help_bot!")).to eq(true)
    expect(Jobs::ChatbotReply.jobs.size).to eq(1)
  end

  it "ignores edits without mentions even in auto-respond categories" do
    SiteSetting.chatbot_auto_respond_categories = post.topic.category_id.to_s

    expect(post.revise(user, raw: "Hello everyone, can someone help me please?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs).to be_empty
  end

  it "ignores edits when disabled or the configured bot is missing" do
    SiteSetting.chatbot_enabled = false
    expect(post.revise(user, raw: "Hello @help_bot, can you help?")).to eq(true)
    SiteSetting.chatbot_enabled = true
    bot_user.update!(username: "renamed_bot")
    expect(post.reload.revise(user, raw: "Hello @help_bot, can you help me please?")).to eq(true)

    expect(Jobs::ChatbotReply.jobs).to be_empty
  end

  it "ignores the bot's own edits" do
    post.update!(user: bot_user)

    expect(post.revise(bot_user, raw: "Hello @help_bot, can you help?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs).to be_empty
  end

  it "only replies to edited whispers when enabled" do
    user.update!(admin: true)
    post.update!(post_type: Post.types[:whisper])
    SiteSetting.chatbot_can_trigger_from_whisper = false

    expect(post.revise(user, raw: "Hello @help_bot, can you help?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs).to be_empty

    expect(post.reload.revise(user, raw: "Hello everyone, can you help?")).to eq(true)
    SiteSetting.chatbot_can_trigger_from_whisper = true
    expect(post.reload.revise(user, raw: "Hello @help_bot, can you help?")).to eq(true)
    expect(Jobs::ChatbotReply.jobs.size).to eq(1)
  end
end

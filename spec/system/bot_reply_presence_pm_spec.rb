# frozen_string_literal: true

describe "Chatbot PM presence indicator", type: :system do
  before { enable_current_plugin }

  fab!(:current_user) { Fabricate(:user, username: "pm_user") }
  fab!(:bot_user, :user)
  fab!(:pm_topic) { Fabricate(:private_message_topic, user: current_user, recipient: bot_user) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    Jobs.run_immediately!

    SiteSetting.presence_enabled = true
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_permitted_in_private_messages = true
    SiteSetting.chatbot_bot_user = bot_user.username
    SiteSetting.chatbot_reply_job_time_delay = 0

    ::DiscourseChatbot::OpenAiBotBasic
      .any_instance
      .stubs(:ask)
      .returns({ reply: "bot reply", inner_thoughts: nil })
    ::DiscourseChatbot::OpenAiBotRag
      .any_instance
      .stubs(:ask)
      .returns({ reply: "bot reply", inner_thoughts: nil })
    ::DiscourseChatbot::PostReplyCreator.any_instance.stubs(:create)

    sign_in(current_user)
  end

  it "shows a replying indicator for the bot in a PM" do
    post =
      PostCreator.create!(current_user, topic_id: pm_topic.id, raw: "Hello @#{bot_user.username}")

    opts = ::DiscourseChatbot::PostEvaluation.new.trigger_response(post)
    expect(opts).to be_present
    ::Jobs::ChatbotReply.new.execute(opts)

    wait_for(timeout: 5) do
      PresenceChannel
        .new("/discourse-presence/reply/#{pm_topic.id}")
        .user_ids
        &.include?(bot_user.id)
    end

    topic_page.visit_topic(pm_topic)

    expect(topic_page).to have_css(
      ".topic-above-footer-buttons-outlet.presence .presence-avatars [data-user-card='#{bot_user.username}']",
      wait: 5,
    )
  end
end

# frozen_string_literal: true
require_relative '../../plugin_helper'

RSpec.configure do |config|
  config.prepend_before(:suite) do
    User.find_by(username: "Chatbot") || Fabricate(:user, username: "Chatbot")
  end
end

describe ::DiscourseChatbot::EscalateToStaffFunction do
  fab!(:user)
  let(:bot_user) { Fabricate(:user) }
  let(:chatbot_user) { User.find_by(username: "Chatbot") }

  before do
    SiteSetting.chatbot_bot_user = chatbot_user.username
  end

  it "returns an error if fired from a Post" do
    opts = { type: ::DiscourseChatbot::POST }
    
    expect(subject.process({}, opts)).to eq(I18n.t("chatbot.prompt.function.escalate_to_staff.wrong_type_error"))
  end

  it "creates a Private Message" do
    SiteSetting.chatbot_escalate_to_staff_groups = "2"
    opts = { type: ::DiscourseChatbot::MESSAGE }
    opts[:topic_or_channel_id] = 1
    opts[:user_id] = user.id
    opts[:bot_user_id] = bot_user.id
    opts[:reply_to_message_or_post_id] = 1
    opts[:trust_level] = ::DiscourseChatbot::TRUST_LEVELS[0]
    ::Chat::Channel.stubs(:find).returns({})
    described_class.any_instance.stubs(:get_messages).returns(["this", "is", "a", "test"])
    described_class.any_instance.stubs(:generate_transcript).returns("this is a test")
    described_class.any_instance.stubs(:generate_escalation_title).returns("Test enquiry")

    expect { subject.process({}, opts) }.to change { Topic.count }.by(1)
    expect(Topic.last.title).to eq("#{I18n.t("chatbot.prompt.function.escalate_to_staff.title")}: Test enquiry")
    expect(Topic.last.archetype).to eq(Archetype.private_message)
  end

  it "returns a cooldown error without escalating when within cooldown period" do
    SiteSetting.chatbot_escalate_to_staff_cool_down_period = 1

    Fabricate(
      :user_custom_field,
      user: user,
      name: ::DiscourseChatbot::CHATBOT_LAST_ESCALATION_DATE_CUSTOM_FIELD,
      value: 2.hours.ago.utc.to_s
    )

    opts = {
      type: ::DiscourseChatbot::MESSAGE,
      topic_or_channel_id: 1,
      user_id: user.id,
      bot_user_id: bot_user.id,
      reply_to_message_or_post_id: 1,
      trust_level: ::DiscourseChatbot::TRUST_LEVELS[0]
    }

    ::Chat::Channel.expects(:find).never

    result = nil
    expect { result = subject.process({}, opts) }.not_to change { Topic.count }

    expect(result).to eq(
      {
        answer: {
          result: I18n.t("chatbot.prompt.function.escalate_to_staff.cool_down_error"),
          topic_ids_found: [],
          post_ids_found: [],
          non_post_urls_found: []
        },
        token_usage: 0
      }
    )
  end
end

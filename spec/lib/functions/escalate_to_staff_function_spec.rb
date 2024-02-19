# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::EscalateToStaffFunction do
  let(:user) { Fabricate(:user) }
  let(:bot_user) { Fabricate(:user) }

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
    ::Chat::Channel.stubs(:find).returns({})
    described_class.any_instance.stubs(:get_messages).returns(["this", "is", "a", "test"])
    described_class.any_instance.stubs(:generate_transcript).returns("this is a test")

    expect { subject.process({}, opts) }.to change { Topic.count }.by(1)
    expect(Topic.last.title).to eq(I18n.t("chatbot.prompt.function.escalate_to_staff.title"))
    expect(Topic.last.archetype).to eq(Archetype.private_message)
  end
end

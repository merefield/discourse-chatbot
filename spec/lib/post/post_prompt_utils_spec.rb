# frozen_string_literal: true

require_relative '../../plugin_helper'

describe ::DiscourseChatbot::PostPromptUtils do
  let(:topic) { Fabricate(:topic) }
  let!(:post_1) { Fabricate(:post, topic: topic) }
  let!(:post_2) { Fabricate(:post, topic: topic) }
  let!(:post_3) { Fabricate(:post, topic: topic, reply_to_post_number: 1) }
  let!(:post_4) { Fabricate(:post, topic: topic, reply_to_post_number: 2) }
  let!(:post_5) { Fabricate(:post, topic: topic) }
  let!(:post_6) { Fabricate(:post, topic: topic, reply_to_post_number: 3) }
  let!(:post_7) { Fabricate(:post, topic: topic) }

  before(:each) do
    SiteSetting.chatbot_enabled = true
  end

  it "captures the right history when one post contains a reply to the bot" do
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_1.id)
    expect(past_posts.count).to equal(1)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_3.id)
    expect(past_posts.count).to equal(2)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_5.id)
    expect(past_posts.count).to equal(4)
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_6.id)
    expect(past_posts.count).to equal(3)

    post_5.destroy
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_7.id)
    expect(past_posts.count).to equal(4)
    post_3.destroy
    past_posts = ::DiscourseChatbot::PostPromptUtils.collect_past_interactions(post_7.id)
    expect(past_posts.count).to equal(3)
  end
end

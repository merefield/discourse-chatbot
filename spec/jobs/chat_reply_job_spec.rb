# frozen_string_literal: true

require_relative '../plugin_helper'

describe ::DiscourseChatbot::PostPromptUtils do
  let(:topic) { Fabricate(:topic) }
  let!(:post_1) { Fabricate(:post, topic: topic) }
  let!(:post_2) { Fabricate(:post, topic: topic) }
  let!(:post_3) { Fabricate(:post, topic: topic, reply_to_post_number: 1) }
  let!(:post_4) { Fabricate(:post, topic: topic, reply_to_post_number: 2) }
  let!(:post_5) { Fabricate(:post, topic: topic) }
  let!(:post_6) { Fabricate(:post, topic: topic, reply_to_post_number: 3)}

  before(:all) do
    SiteSetting.chatbot_enabled = true
  end


it "updates the topic excerpt when first post" do
  post = Fabricate(:post, raw: "Some OP content", cooked: "")
  post.topic.update_excerpt("Incorrect")

  Jobs::ProcessPost.new.execute(post_id: post.id)
  expect(post.topic.reload.excerpt).to eq("Some OP content")

  post2 = Fabricate(:post, raw: "Some reply content", cooked: "", topic: post.topic)
  Jobs::ProcessPost.new.execute(post_id: post2.id)
  expect(post.topic.reload.excerpt).to eq("Some OP content")
end
end

describe "#enqueue_pull_hotlinked_images" do
fab!(:post) { Fabricate(:post, created_at: 20.days.ago) }
let(:job) { Jobs::ProcessPost.new }



Mentionables::GoogleAuthorization.stubs(:authorizer).returns(Google::Auth::ServiceAccountCredentials.new)
Oneboxer.stubs(:preview).returns("<aside class=\"onebox allowlistedgeneric\" data-onebox-src=\"https://example.com/comm-link/transmission/Roadmap-Roundup\">\n  <header class=\"source\">\n\n      <a href=\"https://example.com/comm-link/transmission/Roadmap-Roundup\" target=\"_blank\" rel=\"nofollow ugc noopener\">Roadmap Roundup</a>\n  </header>\n\n  <article class=\"onebox-body\">\n    <img src=\"https://example.com/media/qoxio5lo5vxv3r/channel_item_full/ROADMAPBANNER.jpg\" class=\"thumbnail\">\n\n<h3><a href=\"https://example.com/comm-link/transmission/Roadmap-Roundup\" target=\"_blank\" rel=\"nofollow ugc noopener\">Roadmap Roundup</a></h3>\n\n  <p>Example is the official go-to website for all news  about roadmap stuff.</p>\n\n\n  </article>\n\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n\n  <div style=\"clear: both\"></div>\n</aside>\n")
Google::Apis::SheetsV4::SheetsService.any_instance.stubs(:get_spreadsheet_values).returns(stub('values',
  values: [["url"],
  ["https://example.com/tomato"]]
))
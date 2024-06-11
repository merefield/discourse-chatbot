# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::ForumSearchFunction do
  let(:topic_1) { Fabricate(:topic, title: "weather in southern Europe") }
  let(:post_1) { Fabricate(:post, topic: topic_1, raw: "the rain in spain", post_number: 1) }
  let(:post_2) { Fabricate(:post, topic: topic_1, raw: "falls mainly", post_number: 2) }
  let(:post_3) { Fabricate(:post, topic: topic_1,  raw: "on the plain", post_number: 3) }
  let(:post_4) { Fabricate(:post, topic: topic_1,  raw: "or so they say!", post_number: 4) }
  let(:topic_2) { Fabricate(:topic, title: "weather in northern Europe") }
  let(:post_5) { Fabricate(:post, topic: topic_2, raw: "rains everywhere https://example.com/t/slug/#{post_2.topic_id}/#{post_2.post_number} ", post_number: 1) }
  let(:topic_3) { Fabricate(:topic, title: "nothing to do with the weather")}
  let(:post_6) { Fabricate(:post, topic: topic_3, raw: "cars go fast", post_number: 1) }

  before(:each) do
    ::DiscourseChatbot::PostEmbeddingProcess.any_instance.stubs(:semantic_search).returns(
      [
        {
          post_id: post_3.id,
          score: 0.9
        },
        {
          post_id:  post_5.id,
          score: 0.8
        }
      ]
    )
    ::DiscourseChatbot::PostEmbeddingProcess.any_instance.stubs(:in_scope).returns(true)
    ::DiscourseChatbot::PostEmbeddingProcess.any_instance.stubs(:is_valid).returns(true)
  end

  it "returns contents of a high ranking Post" do
    SiteSetting.chatbot_forum_search_function_results_content_type = "post"
    args = { 'query' => 'rain' }
    # TODO if we don't inspect the posts, they will not be instantiated properly
    expect(post_1).not_to be_nil
    expect(post_2).not_to be_nil
    expect(post_3).not_to be_nil
    expect(post_4).not_to be_nil
    expect(post_5).not_to be_nil
    expect(post_6).not_to be_nil
    expect(topic_1).not_to be_nil
    expect(topic_2).not_to be_nil
    expect(topic_3).not_to be_nil
    expect(subject.process(args)[:topic_ids_found]).to eq([post_2.topic_id])
    expect(subject.process(args)[:post_ids_found]).to include(post_5.id)
    expect(subject.process(args)[:post_ids_found]).to include(post_3.id)
    expect(subject.process(args)[:post_ids_found]).to include(post_2.id)
    expect(subject.process(args)[:post_ids_found]).not_to include(post_4.id)
    expect(subject.process(args)[:result]).to include(post_3.raw)
  end

  it "returns contents of a high ranking Topic" do
    SiteSetting.chatbot_forum_search_function_results_content_type = "topic"
    SiteSetting.chatbot_forum_search_function_results_topic_max_posts_count_strategy = "just_enough"
    args = { 'query' => 'rain' }
    # TODO if we don't inspect the posts, they will not be instantiated properly
    expect(post_1).not_to be_nil
    expect(post_2).not_to be_nil
    expect(post_3).not_to be_nil
    expect(post_4).not_to be_nil
    expect(post_5).not_to be_nil
    expect(post_6).not_to be_nil
    expect(topic_1).not_to be_nil
    expect(topic_2).not_to be_nil
    expect(topic_3).not_to be_nil
    expect(subject.process(args)[:topic_ids_found]).to include(topic_1.id)
    expect(subject.process(args)[:result]).to include(post_1.raw)
    expect(subject.process(args)[:result]).to include(post_2.raw)
    expect(subject.process(args)[:result]).to include(post_3.raw)
    expect(subject.process(args)[:result]).to include(topic_1.title)
    expect(subject.process(args)[:result]).not_to include(topic_3.title)
    expect(subject.process(args)[:result]).not_to include(post_4.raw)
  end

  it "finds urls with a post id" do
    expect(subject.find_post_and_topic_ids_from_raw_urls(post_5.raw)).to eq([[post_2.topic_id], [post_2.id]])
  end
end
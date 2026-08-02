# frozen_string_literal: true

require_relative "../../plugin_helper"

RSpec.shared_context "with location plugin stubs" do
  around do |example|
    original_locations = Object.const_get(:Locations) if Object.const_defined?(:Locations, false)
    Object.send(:remove_const, :Locations) if original_locations
    Object.const_set(:Locations, Module.new)
    Locations.const_set(:TopicLocation, Class.new)
    Locations.const_set(:UserLocation, Class.new)
    Locations.const_set(:TopicLocationProcess, Class.new)
    Locations.const_set(:UserLocationProcess, Class.new)
    example.run
  ensure
    Object.send(:remove_const, :Locations)
    Object.const_set(:Locations, original_locations) if original_locations
  end
end

RSpec.describe DiscourseChatbot::Functions::ForumTopicSearchFromTopicLocationFunction do
  subject(:search_function) { described_class.new }

  include_context "with location plugin stubs"

  fab!(:target_topic, :topic)
  fab!(:nearby_topic, :topic)

  it "returns nearby topics relative to the supplied topic" do
    target_location = stub(to_coordinates: [51.5, -0.1])
    nearby_location = stub(address: "London", distance_from: 11.1)
    Locations::TopicLocation
      .stubs(:find_by)
      .with(topic_id: target_topic.id)
      .returns(target_location)
    Locations::TopicLocation
      .stubs(:find_by)
      .with(topic_id: nearby_topic.id)
      .returns(nearby_location)
    Locations::TopicLocationProcess
      .stubs(:search_topics_from_topic_location)
      .with(target_topic.id, 500)
      .returns([nearby_topic.id])

    result = search_function.process("topic_id" => target_topic.id)

    expect(result[:answer]).to include(
      nearby_topic.title,
      nearby_location.address,
      "/t/slug/#{nearby_topic.id}",
    )
    expect(result[:token_usage]).to eq(0)
  end

  it "returns the topic-location search error when the search fails" do
    Locations::TopicLocation.stubs(:find_by).with(topic_id: target_topic.id).returns(stub)
    Locations::TopicLocationProcess.stubs(:search_topics_from_topic_location).raises(StandardError)

    result = search_function.process("topic_id" => target_topic.id)

    expect(result).to eq(
      answer:
        I18n.t(
          "chatbot.prompt.function.forum_topic_search_from_topic_location.error",
          query: target_topic.id,
        ),
      token_usage: 0,
    )
  end
end

RSpec.describe DiscourseChatbot::Functions::ForumUserSearchFromTopicLocationFunction do
  subject(:search_function) { described_class.new }

  include_context "with location plugin stubs"

  fab!(:target_topic, :topic)
  fab!(:nearby_user, :user)

  it "has a unique user-from-topic function name" do
    expect(search_function.name).to eq("forum_user_search_from_topic_location")
  end

  it "returns nearby users relative to the supplied topic" do
    target_location = stub(to_coordinates: [51.5, -0.1])
    nearby_location = stub(distance_from: 11.1)
    Locations::TopicLocation
      .stubs(:find_by)
      .with(topic_id: target_topic.id)
      .returns(target_location)
    Locations::UserLocation.stubs(:find_by).with(user_id: nearby_user.id).returns(nearby_location)
    Locations::UserLocationProcess
      .stubs(:search_users_from_topic_location)
      .with(target_topic.id, 500)
      .returns([nearby_user.id])

    result = search_function.process("topic_id" => target_topic.id)

    expect(result[:answer]).to include("@#{nearby_user.username}")
    expect(result[:token_usage]).to eq(0)
  end
end

RSpec.describe DiscourseChatbot::Functions::ForumTopicSearchFromUserLocationFunction do
  subject(:search_function) { described_class.new }

  include_context "with location plugin stubs"

  fab!(:target_user, :user)
  fab!(:nearby_topic, :topic)

  it "returns nearby topics with the translated answer" do
    target_location = stub(to_coordinates: [51.5, -0.1])
    nearby_location = stub(address: "London", distance_from: 11.1)
    Locations::UserLocation.stubs(:find_by).with(user_id: target_user.id).returns(target_location)
    Locations::TopicLocation
      .stubs(:find_by)
      .with(topic_id: nearby_topic.id)
      .returns(nearby_location)
    Locations::UserLocationProcess
      .stubs(:search_topics_from_user_location)
      .with(target_user.id, 500)
      .returns([nearby_topic.id])

    result = search_function.process("username" => target_user.username)

    expect(result[:answer]).to include(
      nearby_topic.title,
      nearby_location.address,
      "/t/slug/#{nearby_topic.id}",
    )
    expect(result[:token_usage]).to eq(0)
  end
end

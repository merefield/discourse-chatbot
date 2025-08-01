# frozen_string_literal: true
require_relative '../plugin_helper'

RSpec.describe DiscourseChatbot::PostEmbeddingProcess do
  describe 'scope' do

    let(:category_in_scope) { Fabricate(:category) }
    let(:category_out_of_scope  ) { Fabricate(:category) }
    let(:topic_in_scope) { Fabricate(:topic, category: category_in_scope) }
    let(:topic_out_of_scope) { Fabricate(:topic, category: category_out_of_scope) }

    let(:post_in_scope) { Fabricate(:post, topic: topic_in_scope) }
    let(:post_out_of_scope) { Fabricate(:post, topic: topic_out_of_scope) }

    let(:user) { Fabricate(:user) }
    let(:group) { Fabricate(:group) }
    let(:group_user) { Fabricate(:group_user, user: user, group: group) }

    let(:some_other_user) { Fabricate(:user) }

    let(:category_in_benchmark_scope) { Fabricate(:private_category, group: group, permission_type: CategoryGroup.permission_types[:full]) }
    let(:topic_in_benchmark_scope) { Fabricate(:topic, category: category_in_benchmark_scope) }
    let(:post_in_benchmark_scope) { Fabricate(:post, topic: topic_in_benchmark_scope) }

    it "includes the right posts in scope when using categories strategy" do
      SiteSetting.chatbot_embeddings_strategy = "benchmark_user"
      
      # TODO if we don't inspect group_user, it will be nil and the test will then fail!  Why?
      expect(group_user).not_to be_nil

      described_class.any_instance.stubs(:benchmark_user).returns(user)
      expect(subject.in_benchmark_user_scope(post_in_benchmark_scope.id)).to eq(true)
      expect(subject.in_scope(post_in_benchmark_scope.id)).to eq(true)

      described_class.any_instance.stubs(:benchmark_user).returns(some_other_user)
      expect(subject.in_benchmark_user_scope(post_in_benchmark_scope.id)).to eq(false)
      expect(subject.in_scope(post_in_benchmark_scope.id)).to eq(false)
    end

    it "includes the right posts in scope when using categories strategy" do
      SiteSetting.chatbot_embeddings_strategy = "categories"
      SiteSetting.chatbot_embeddings_categories = "#{category_in_scope.id}"
      expect(subject.in_categories_scope(post_in_scope.id)).to eq(true)
      expect(subject.in_scope(post_in_scope.id)).to eq(true)
      expect(subject.in_categories_scope(post_out_of_scope.id)).to eq(false)
      expect(subject.in_scope(post_out_of_scope.id)).to eq(false)
    end
  end

  describe 'validity' do
    it "checks if a post embedding is valid" do
      SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-ada-002"
      freeze_time(3.days.ago)
      post = Fabricate(:post)
      freeze_time(2.days.ago)
      post_embedding = ::DiscourseChatbot::PostEmbedding.create!(post_id: post.id, model: "text-embedding-3-small", embedding: "[#{(1..1536).to_a.join(",")}]")
      expect(subject.is_valid(post.id)).to eq(false)
      freeze_time(1.days.ago)
      post_embedding = ::DiscourseChatbot::PostEmbedding.upsert({post_id: post.id, model: "text-embedding-ada-002", embedding: "[#{(1..1536).to_a.join(",")}]"}, on_duplicate: :update, unique_by: :post_id)
      expect(subject.is_valid(post.id)).to eq(true)
    end
  end
end

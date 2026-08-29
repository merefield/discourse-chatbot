# frozen_string_literal: true
require_relative "../plugin_helper"

RSpec.describe DiscourseChatbot::Post::PostEmbeddingProcess do
  subject(:embedding_process) { described_class.new }

  describe "scope" do
    let(:category_in_scope) { Fabricate(:category) }
    let(:category_out_of_scope) { Fabricate(:category) }
    let(:topic_in_scope) { Fabricate(:topic, category: category_in_scope) }
    let(:topic_out_of_scope) { Fabricate(:topic, category: category_out_of_scope) }

    let(:post_in_scope) { Fabricate(:post, topic: topic_in_scope) }
    let(:post_out_of_scope) { Fabricate(:post, topic: topic_out_of_scope) }

    fab!(:user)
    fab!(:group)
    let(:group_user) { Fabricate(:group_user, user: user, group: group) }

    let(:some_other_user) { Fabricate(:user) }

    let(:category_in_benchmark_scope) do
      Fabricate(
        :private_category,
        group: group,
        permission_type: CategoryGroup.permission_types[:full],
      )
    end
    let(:topic_in_benchmark_scope) { Fabricate(:topic, category: category_in_benchmark_scope) }
    let(:post_in_benchmark_scope) { Fabricate(:post, topic: topic_in_benchmark_scope) }

    it "includes the right posts in scope when using categories strategy" do
      SiteSetting.chatbot_embeddings_strategy = "benchmark_user"

      # TODO if we don't inspect group_user, it will be nil and the test will then fail!  Why?
      expect(group_user).not_to be_nil

      described_class.any_instance.stubs(:benchmark_user).returns(user)
      expect(embedding_process.in_benchmark_user_scope(post_in_benchmark_scope.id)).to eq(true)
      expect(embedding_process.in_scope(post_in_benchmark_scope.id)).to eq(true)

      described_class.any_instance.stubs(:benchmark_user).returns(some_other_user)
      expect(embedding_process.in_benchmark_user_scope(post_in_benchmark_scope.id)).to eq(false)
      expect(embedding_process.in_scope(post_in_benchmark_scope.id)).to eq(false)
    end

    it "includes the right posts in scope when using categories strategy" do
      SiteSetting.chatbot_embeddings_strategy = "categories"
      SiteSetting.chatbot_embeddings_categories = "#{category_in_scope.id}"
      expect(embedding_process.in_categories_scope(post_in_scope.id)).to eq(true)
      expect(embedding_process.in_scope(post_in_scope.id)).to eq(true)
      expect(embedding_process.in_categories_scope(post_out_of_scope.id)).to eq(false)
      expect(embedding_process.in_scope(post_out_of_scope.id)).to eq(false)
    end
  end

  describe "validity" do
    it "requires the stored provider and model to match the current configuration" do
      SiteSetting.chatbot_embeddings_provider = "open_ai"
      SiteSetting.chatbot_open_ai_embeddings_model = "text-embedding-ada-002"
      post = Fabricate(:post)
      post_embedding =
        ::DiscourseChatbot::PostEmbedding.create!(
          post_id: post.id,
          model: "text-embedding-3-small",
          provider: "open_ai",
          embedding: "[#{(1..1536).to_a.join(",")}]",
        )
      expect(embedding_process.is_valid(post.id)).to eq(false)
      post_embedding.update!(model: "text-embedding-ada-002", provider: "google_gemini")
      expect(embedding_process.is_valid(post.id)).to eq(false)

      post_embedding.update!(provider: "open_ai")
      expect(embedding_process.is_valid(post.id)).to eq(true)
    end
  end
end

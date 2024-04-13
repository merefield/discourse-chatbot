# frozen_string_literal: true
require_relative '../plugin_helper'

RSpec.describe DiscourseChatbot::EmbeddingCompletionist do
  describe 'bookmark' do

    let(:post_1) { Fabricate(:post) }
    let(:post_2) { Fabricate(:post) }
    let(:post_3) { Fabricate(:post) }
    let(:post_4) { Fabricate(:post) }
    let(:post_5) { Fabricate(:post) }
    @original_constant = DiscourseChatbot::EMBEDDING_PROCESS_POSTS_CHUNK

    after(:each) do
      DiscourseChatbot.const_set(:EMBEDDING_PROCESS_POSTS_CHUNK, @original_constant)
    end

    it 'should process a chunk each time its called and reset to start once it gets to end' do

      expect(post_1).to be_present
      expect(post_2).to be_present
      expect(post_3).to be_present
      expect(post_4).to be_present
      expect(post_5).to be_present

      DiscourseChatbot.const_set(:EMBEDDING_PROCESS_POSTS_CHUNK, 3)
      DiscourseChatbot::PostEmbeddingsBookmark.new(post_id: post_1.id).save!
      expect(described_class.process).to eq(post_4.id)
      bookmark = DiscourseChatbot::PostEmbeddingsBookmark.first
      expect(bookmark).to be_present
      expect(bookmark.post_id).to eq(post_4.id)
      expect(described_class.process).to eq(post_1.id)
      expect(described_class.process).to eq(post_4.id)
    end
  end
end

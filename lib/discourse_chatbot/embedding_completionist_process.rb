# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class EmbeddingCompletionist

    def self.process
      bookmarked_post_id = ::DiscourseChatbot::PostEmbeddingsBookmark.first&.post_id || 1

      post_ids_for_check_this_time = (bookmarked_post_id..(bookmarked_post_id + EMBEDDING_PROCESS_CHUNK)).to_a

      benchmark_user = ::DiscourseChatbot::PostEmbeddingProcess.new.benchmark_user

      post_ids_for_check_this_time.each do |post_id|
        Jobs.enqueue(:chatbot_post_embedding, id: post_id)
        bookmarked_post_id += 1
        bookmarked_post_id = 1 if bookmarked_post_id > ::Post.maximum(:id)
      end

      bookmark = ::DiscourseChatbot::PostEmbeddingsBookmark.first

      if bookmark
        bookmark.post_id = bookmarked_post_id
      else
        bookmark = ::DiscourseChatbot::PostEmbeddingsBookmark.new(post_id: bookmarked_post_id)
      end

      bookmark.save!
    end
  end
end

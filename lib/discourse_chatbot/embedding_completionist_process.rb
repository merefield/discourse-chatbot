# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class EmbeddingCompletionist

    def self.process
      bookmarked_post_id = ::DiscourseChatbot::PostEmbeddingsBookmark.first&.post_id || ::Post.first.id

      post_range = ::Post.where("id >= ?", bookmarked_post_id).order(:id).limit(EMBEDDING_PROCESS_CHUNK).pluck(:id)

      post_range.each do |post_id|
        Jobs.enqueue(:chatbot_post_embedding, id: post_id)

        bookmarked_post_id = ::Post.where("id > ?", post_id).order(:id).limit(1).pluck(:id)&.first
      end

      bookmarked_post_id = ::Post.first.id if bookmarked_post_id.nil?
           
      bookmark = ::DiscourseChatbot::PostEmbeddingsBookmark.first

      if bookmark
        bookmark.post_id = bookmarked_post_id
      else
        bookmark = ::DiscourseChatbot::PostEmbeddingsBookmark.new(post_id: bookmarked_post_id)
      end

      bookmark.save!
      ::DiscourseChatbot.progress_debug_message <<~EOS
      ---------------------------------------------------------------------------------------------------------------
      Post Embeddings Completion Bookmark is now at Post: #{bookmark.post_id}
      ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      EOS
      bookmark.post_id
    end
  end
end

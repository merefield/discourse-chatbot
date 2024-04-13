# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class EmbeddingCompletionist

    def self.process
      process_posts
      process_topics
    end

    def self.process_topics
      bookmarked_topic_id = ::DiscourseChatbot::TopicEmbeddingsBookmark.first&.topic_id || ::Topic.first.id

      limit = EMBEDDING_PROCESS_POSTS_CHUNK * (Topic.count/Post.count)

      topic_range = ::Topic.where("id >= ?", bookmarked_topic_id).order(:id).limit(limit.ceil).pluck(:id)

      topic_range.each do |topic_id|
        Jobs.enqueue(:chatbot_topic_title_embedding, id: topic_id)

        bookmarked_topic_id = ::Topic.where("id > ?", topic_id).order(:id).limit(1).pluck(:id)&.first
      end

      bookmarked_topic_id = ::Topic.first.id if bookmarked_topic_id.nil?
           
      bookmark = ::DiscourseChatbot::TopicEmbeddingsBookmark.first

      if bookmark
        bookmark.topic_id = bookmarked_topic_id
      else
        bookmark = ::DiscourseChatbot::TopicEmbeddingsBookmark.new(topic_id: bookmarked_topic_id)
      end

      bookmark.save!
      ::DiscourseChatbot.progress_debug_message <<~EOS
      ---------------------------------------------------------------------------------------------------------------
      Topic Embeddings Completion Bookmark is now at Post: #{bookmark.topic_id}
      ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      EOS
      bookmark.topic_id
    end

    def self.process_posts
      bookmarked_post_id = ::DiscourseChatbot::PostEmbeddingsBookmark.first&.post_id || ::Post.first.id

      post_range = ::Post.where("id >= ?", bookmarked_post_id).order(:id).limit(EMBEDDING_PROCESS_POSTS_CHUNK).pluck(:id)

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

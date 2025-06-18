# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class PostEmbeddingProcess < EmbeddingProcess

    def upsert(post_id)
      if in_scope(post_id)
        if !is_valid(post_id)

          embedding_vector = get_embedding(post_id)
  
          ::DiscourseChatbot::PostEmbedding.upsert({ post_id: post_id, model: SiteSetting.chatbot_open_ai_embeddings_model, embedding: "#{embedding_vector}" }, on_duplicate: :update, unique_by: :post_id)

          ::DiscourseChatbot.progress_debug_message <<~EOS
          ---------------------------------------------------------------------------------------------------------------
          Post Embeddings: I found an embedding that needed populating or updating, id: #{post_id}
          ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
          EOS
        end
      else
        post_embedding = ::DiscourseChatbot::PostEmbedding.find_by(post_id: post_id)
        if post_embedding
          ::DiscourseChatbot.progress_debug_message <<~EOS
          ---------------------------------------------------------------------------------------------------------------
          Post Embeddings: I found a Post that was out of scope for embeddings, so deleted the embedding, id: #{post_id}
          ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
          EOS
          post_embedding.delete
        end
      end
    end

    def get_embedding(post_id)
      post = ::Post.find_by(id: post_id)
      text = post.raw[0..SiteSetting.chatbot_open_ai_embeddings_char_limit]

      get_embedding_from_api(text)
    end

    def semantic_search(query)
      self.setup_api

      response = @client.embeddings(
        parameters: {
          model: @model_name,
          input: query[0..SiteSetting.chatbot_open_ai_embeddings_char_limit]
        }
       )

      query_vector = response.dig("data", 0, "embedding")

      begin
        threshold = SiteSetting.chatbot_forum_search_function_similarity_threshold
        results = 
          DB.query(<<~SQL, query_embedding: query_vector, threshold: threshold, limit: 100)
            SELECT
              post_id,
              p.user_id,
              embedding <=> '[:query_embedding]' as cosine_distance
            FROM
              chatbot_post_embeddings
            INNER JOIN
              posts p
            ON
              post_id = p.id
            WHERE
              (1 -  (embedding <=> '[:query_embedding]')) > :threshold
            ORDER BY
              embedding <=> '[:query_embedding]'
            LIMIT :limit
          SQL
      rescue PG::Error => e
        Rails.logger.error(
          "Error #{e} querying embeddings for search #{query}",
        )
       raise MissingEmbeddingError
      end

      # exclude if not in scope for embeddings (job hasn't caught up yet)
      results = results.filter { |result| in_scope(result.post_id) && is_valid( result.post_id)}

      results = results.map {|p| { post_id: p.post_id, user_id: p.user_id, score: (1 - p.cosine_distance), rank_modifier: 0, source: "semantic" } }

      max_semantic_score = results.map { |r| r[:score] }.max || 1

      if SiteSetting.chatbot_forum_search_function_hybrid_search
        search = Search.new(query, { search_type: :full_page })

        keyword_search = search.execute.posts.pluck(:id, :user_id, :score)

        keyword_search_array_of_hashes = keyword_search.map { |id, user_id, score| {post_id: id, user_id: user_id, score: score, rank_modifier: 0, source: "keyword" } }

        keyword_search_max_score = keyword_search_array_of_hashes.map { |k| k[:score] }.max || 1

        keyword_search_array_of_hashes = keyword_search_array_of_hashes.each { |k| k[:score] = k[:score] / keyword_search_max_score * max_semantic_score}

        keyword_search_array_of_hashes.each do |k|
          results << k if !results.map { |r| r[:post_id] }.include?(k[:post_id])
        end
      end

      if ["group_promotion", "both"].include?(SiteSetting.chatbot_forum_search_function_reranking_strategy)
        high_ranked_users = []

        SiteSetting.chatbot_forum_search_function_reranking_groups.split("|").each do |g|
          high_ranked_users = high_ranked_users | GroupUser.where(group_id: g).pluck(:user_id)
        end

        results.each do |r|
          r[:rank_modifier] += 1 if high_ranked_users.include?(r[:user_id])
        end
      end

      if ["tag_promotion", "both"].include?(SiteSetting.chatbot_forum_search_function_reranking_strategy)
        high_ranked_tags = SiteSetting.chatbot_forum_search_function_reranking_tags.split("|")

        results.each do |r|
          post = ::Post.find_by(id: r[:post_id])
          tag_ids = ::TopicTag.where(topic_id: post.topic_id).pluck(:tag_id)
          tags = ::Tag.where(id: tag_ids).pluck(:name)
          r[:rank_modifier] += 1 if (high_ranked_tags & tags).any?
        end
      end

      results.sort_by { |r| [r[:rank_modifier], r[:score]] }.reverse.first(SiteSetting.chatbot_forum_search_function_max_results)
    end

    def in_scope(post_id)
      return false if !::Post.find_by(id: post_id).present? 
      if SiteSetting.chatbot_embeddings_strategy == "categories"
        return false if !in_categories_scope(post_id)
      else
        return false if !in_benchmark_user_scope(post_id)
      end
      true
    end
  
    def is_valid(post_id)
      post = ::Post.find_by(id: post_id)
      embedding_record = ::DiscourseChatbot::PostEmbedding.find_by(post_id: post_id)
      return false if !embedding_record.present?
      return false if embedding_record.model != SiteSetting.chatbot_open_ai_embeddings_model
      return false if post.updated_at > embedding_record.updated_at
      true
    end
  
    def in_categories_scope(post_id)
      post = ::Post.find_by(id: post_id)
      return false if post.nil?
      topic = ::Topic.find_by(id: post.topic_id)
      return false if topic.nil?
      return false if topic.archetype == ::Archetype.private_message
      SiteSetting.chatbot_embeddings_categories.split("|").include?(topic.category_id.to_s)
    end
  
    def in_benchmark_user_scope(post_id)
      return false if benchmark_user.nil?
      post = ::Post.find_by(id: post_id)
      return false if post.nil?
      topic = ::Topic.find_by(id: post.topic_id)
      return false if topic.nil?
      return false if topic.archetype == ::Archetype.private_message
      Guardian.new(benchmark_user).can_see?(post)
    end
  end
end

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class PostEmbeddingProcess

    def setup_api
      ::OpenAI.configure do |config|
        config.access_token = SiteSetting.chatbot_open_ai_token
      end
      if !SiteSetting.chatbot_open_ai_embeddings_model_custom_url.blank?
        ::OpenAI.configure do |config|
          config.uri_base = SiteSetting.chatbot_open_ai_embeddings_model_custom_url
        end
      end
      if SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
        ::OpenAI.configure do |config|
          config.api_type = :azure
          config.api_version = SiteSetting.chatbot_open_ai_model_custom_api_version
        end
      end
      @model_name = SiteSetting.chatbot_open_ai_embeddings_model
      @client = ::OpenAI::Client.new
    end

    def upsert(post_id)
      if in_scope(post_id)
        if !is_valid(post_id)

          embedding_vector = get_embedding_from_api(post_id)
  
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

    def get_embedding_from_api(post_id)
      begin
        self.setup_api

        post = ::Post.find_by(id: post_id)
        topic = ::Topic.find_by(id: post.topic_id)
        response = @client.embeddings(
          parameters: {
            model: @model_name,
            input: post.raw[0..SiteSetting.chatbot_open_ai_embeddings_char_limit]
          }
        )

        if response.dig("error")
          error_text = response.dig("error", "message")
          raise StandardError, error_text
        end
      rescue StandardError => e
        Rails.logger.error("Chatbot: Error occurred while attempting to retrieve Embedding for post id '#{post_id}' in topic id '#{topic.id}': #{e.message}")
        raise e
      end

      embedding_vector = response.dig("data", 0, "embedding")
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

        high_ranked_users = []

        SiteSetting.chatbot_forum_search_function_reranking_group_promotion_map.each do |g|
          high_ranked_users = high_ranked_users | GroupUser.where(group_id: g).pluck(:user_id)
        end

        reranked_results = results.filter {|r| high_ranked_users.include?(r.user_id)} + results.filter {|r| !high_ranked_users.include?(r.user_id)}.first(20)

        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} querying embeddings for search #{query}",
          )
         raise MissingEmbeddingError
        end
      reranked_results.map {|p| { post_id: p.post_id, user_id: p.user_id, score: (1 - p.cosine_distance) } }
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
      embedding_record = ::DiscourseChatbot::PostEmbedding.find_by(post_id: post_id)
      return false if !embedding_record.present?
      return false if embedding_record.model != SiteSetting.chatbot_open_ai_embeddings_model
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

    def benchmark_user
      cache_key = "chatbot_benchmark_user"
      benchmark_user = Discourse.cache.fetch(cache_key, expires_in: 1.hour) do
        allowed_group_ids = [0, 10, 11, 12, 13, 14]  # automated groups only
        barred_group_ids = ::Group.where.not(id: allowed_group_ids).pluck(:id) # no custom groups
        unsuitable_users = ::GroupUser.where(group_id: barred_group_ids).pluck(:user_id).uniq # don't choose someone with in a custom group
        safe_users = ::User.where.not(id: unsuitable_users).distinct.pluck(:id) # exclude them and find a suitable vanilla, junior user
        user = ::User.where(id: safe_users).where(trust_level: SiteSetting.chatbot_embeddings_benchmark_user_trust_level, active: true, admin: false, suspended_at: nil)&.last
        if user.nil?
          raise StandardError, "Chatbot: No benchmark user exists for Post embedding suitability check, please add a basic user"
        end
        user
      end

      benchmark_user
    end
  end
end

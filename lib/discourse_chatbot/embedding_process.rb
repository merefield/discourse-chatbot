# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class EmbeddingProcess

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

    def upsert(id)
      raise "Overwrite me!"
    end

    def get_embedding(id)
      raise "Overwrite me!"
    end

    def get_embedding_from_api(text)
      begin
        self.setup_api

        response = @client.embeddings(
          parameters: {
            model: @model_name,
            input: text
          }
        )

        if response.dig("error")
          error_text = response.dig("error", "message")
          raise StandardError, error_text
        end

        # Логируем использование токенов для эмбеддингов
        if SiteSetting.chatbot_enable_token_usage_tracking
          usage = response.dig("usage") || {}
          total_tokens = usage["total_tokens"] || text.split.length
          
          # Используем benchmark пользователя для эмбеддингов
          user_id = benchmark_user&.id || -1
          
          TokenUsageLogger.log_embedding_usage(
            user_id: user_id,
            model_name: @model_name,
            tokens: total_tokens
          )
        end
      rescue StandardError => e
        Rails.logger.error("Chatbot: Error occurred while attempting to retrieve Embedding for post id '#{post_id}' in topic id '#{topic.id}': #{e.message}")
        raise e
      end

      embedding_vector = response.dig("data", 0, "embedding")
    end


    def semantic_search(query)
      raise "Overwrite me!"
    end

    def in_scope(id)
      raise "Overwrite me!"
    end
  
    def is_valid(id)
      raise "Overwrite me!"
    end
  
    def in_categories_scope(id)
      raise "Overwrite me!"
    end
  
    def in_benchmark_user_scope(id)
      raise "Overwrite me!"
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

# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot
  class EmbeddingProcess
    EXPECTED_DIMENSIONS = 1536

    class EmbeddingDimensionError < StandardError
    end

    def self.request_parameters(input)
      model_name = ::DiscourseChatbot.embedding_model_name
      parameters = { model: model_name, input: input }
      parameters[:dimensions] = EXPECTED_DIMENSIONS if model_name == "text-embedding-3-large"
      parameters
    end

    def self.client_config
      ::DiscourseChatbot::LlmClient.client_config(
        provider: SiteSetting.chatbot_embeddings_provider,
        custom_uri_base: SiteSetting.chatbot_open_ai_embeddings_model_custom_url,
        azure:
          SiteSetting.chatbot_embeddings_provider == "open_ai" &&
            SiteSetting.chatbot_open_ai_model_custom_api_type == "azure",
      )
    end

    def self.build_client
      if SiteSetting.chatbot_embeddings_provider == "google_gemini" &&
           SiteSetting.chatbot_open_ai_embeddings_model_custom_url.blank?
        return(
          ::DiscourseChatbot::GeminiEmbeddingClient.new(
            access_token: SiteSetting.chatbot_google_gemini_token,
          )
        )
      end

      ::OpenAI::Client.new(client_config)
    end

    def self.embedding_vector(response)
      vector = response.dig("data", 0, "embedding")
      actual_dimensions = vector.respond_to?(:length) ? vector.length : 0
      return vector if actual_dimensions == EXPECTED_DIMENSIONS

      raise EmbeddingDimensionError,
            "Embedding provider returned #{actual_dimensions} dimensions; expected #{EXPECTED_DIMENSIONS}"
    end

    def setup_api
      @model_name = ::DiscourseChatbot.embedding_model_name
      @client = self.class.build_client
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

        response = @client.embeddings(parameters: self.class.request_parameters(text))

        if response.dig("error")
          error_text = response.dig("error", "message")
          raise StandardError, error_text
        end
      rescue StandardError => e
        Rails.logger.error(
          "Chatbot: Error occurred while attempting to retrieve an embedding: #{e.message}",
        )
        raise
      end

      self.class.embedding_vector(response)
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
      benchmark_user =
        Discourse
          .cache
          .fetch(cache_key, expires_in: 1.hour) do
            allowed_group_ids = [0, 10, 11, 12, 13, 14] # automated groups only
            barred_group_ids = ::Group.where.not(id: allowed_group_ids).pluck(:id) # no custom groups
            unsuitable_users = ::GroupUser.where(group_id: barred_group_ids).pluck(:user_id).uniq # don't choose someone with in a custom group
            safe_users = ::User.where.not(id: unsuitable_users).distinct.pluck(:id) # exclude them and find a suitable vanilla, junior user
            user =
              ::User
                .where(id: safe_users)
                .where(
                  trust_level: SiteSetting.chatbot_embeddings_benchmark_user_trust_level,
                  active: true,
                  admin: false,
                  suspended_at: nil,
                )
                &.last
            if user.nil?
              raise StandardError,
                    "Chatbot: No benchmark user exists for Post embedding suitability check, please add a basic user"
            end
            user
          end

      benchmark_user
    end
  end
end

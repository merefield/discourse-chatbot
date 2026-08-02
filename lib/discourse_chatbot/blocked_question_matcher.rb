# frozen_string_literal: true

require "digest"
require "openai"

module ::DiscourseChatbot
  class BlockedQuestionMatcher
    CACHE_VERSION = 1
    EXAMPLE_BATCH_SIZE = 100

    def evaluate(question)
      return unless SiteSetting.chatbot_blocked_questions_enabled

      evaluation = {
        blocked: false,
        threshold: SiteSetting.chatbot_blocked_questions_similarity_threshold,
        embedding_model: SiteSetting.chatbot_open_ai_embeddings_model,
      }
      return evaluation.merge(outcome: "empty_question") if question.blank?

      examples = configured_examples
      return evaluation.merge(outcome: "no_examples") if examples.empty?

      candidates = cached_candidates(examples)
      query_embedding = embeddings([truncate(question)]).first
      best_match = closest_candidate(query_embedding, candidates)
      return evaluation.merge(outcome: "no_comparable_embedding") if best_match.nil?

      blocked = best_match[:similarity] > evaluation[:threshold]

      evaluation.merge(
        best_match,
        blocked: blocked,
        outcome: blocked ? "blocked" : "below_threshold",
      )
    rescue StandardError => error
      Rails.logger.error(
        "Chatbot: Blocked question matching failed; allowing normal bot processing: #{error.message}",
      )
      {
        blocked: false,
        outcome: "error",
        error: error.message,
        threshold: SiteSetting.chatbot_blocked_questions_similarity_threshold,
        embedding_model: SiteSetting.chatbot_open_ai_embeddings_model,
      }
    end

    private

    def configured_examples
      examples = SiteSetting.chatbot_blocked_question_examples.presence || []
      examples = JSON.parse(examples) if examples.is_a?(String)

      examples.filter_map do |example|
        category = example["category"].to_s.strip
        question = example["example_question"].to_s.strip
        next if category.blank? || question.blank?

        { category: category, question: question }
      end
    end

    def cached_candidates(examples)
      Discourse
        .cache
        .fetch(cache_key(examples), expires_in: 1.day) do
          example_embeddings = embeddings(examples.map { |example| truncate(example[:question]) })

          examples
            .zip(example_embeddings)
            .map { |example, embedding| example.merge(embedding: embedding) }
        end
    end

    def cache_key(examples)
      configuration = {
        version: CACHE_VERSION,
        model: SiteSetting.chatbot_open_ai_embeddings_model,
        char_limit: SiteSetting.chatbot_open_ai_embeddings_char_limit,
        custom_url: SiteSetting.chatbot_open_ai_embeddings_model_custom_url,
        api_type: SiteSetting.chatbot_open_ai_model_custom_api_type,
        api_version: SiteSetting.chatbot_open_ai_model_custom_api_version,
        examples: examples,
      }

      "chatbot_blocked_question_examples_#{Digest::SHA256.hexdigest(JSON.generate(configuration))}"
    end

    def embeddings(inputs)
      inputs
        .each_slice(EXAMPLE_BATCH_SIZE)
        .flat_map do |batch|
          response =
            client.embeddings(
              parameters: {
                model: SiteSetting.chatbot_open_ai_embeddings_model,
                input: batch,
              },
            )

          raise StandardError, response.dig("error", "message") if response["error"]

          data = response.fetch("data").sort_by { |item| item.fetch("index") }
          if data.length != batch.length
            raise StandardError, "Embedding provider returned an unexpected result count"
          end

          data.map { |item| item.fetch("embedding") }
        end
    end

    def client
      @client ||=
        begin
          azure = SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
          config = {
            access_token: SiteSetting.chatbot_open_ai_token,
            uri_base:
              SiteSetting.chatbot_open_ai_embeddings_model_custom_url.presence ||
                OpenAI::Configuration::DEFAULT_URI_BASE,
            api_type: azure ? :azure : :open_ai,
            api_version: azure ? SiteSetting.chatbot_open_ai_model_custom_api_version : "v1",
            log_errors: SiteSetting.chatbot_enable_verbose_rails_logging != "off",
          }

          OpenAI::Client.new(config)
        end
    end

    def truncate(text)
      text.to_s.first([SiteSetting.chatbot_open_ai_embeddings_char_limit.to_i, 1].max)
    end

    def closest_candidate(query_embedding, candidates)
      candidates
        .filter_map do |candidate|
          distance = cosine_distance(query_embedding, candidate[:embedding])
          candidate.except(:embedding).merge(similarity: 1.0 - distance) if distance
        end
        .max_by { |candidate| candidate[:similarity] }
    end

    def cosine_distance(left, right)
      return if left.blank? || left.length != right&.length

      dot_product = 0.0
      left_magnitude = 0.0
      right_magnitude = 0.0

      left
        .zip(right)
        .each do |left_value, right_value|
          dot_product += left_value * right_value
          left_magnitude += left_value * left_value
          right_magnitude += right_value * right_value
        end

      denominator = Math.sqrt(left_magnitude) * Math.sqrt(right_magnitude)
      1.0 - (dot_product / denominator) if denominator.nonzero?
    end
  end
end

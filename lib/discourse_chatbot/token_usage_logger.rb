# frozen_string_literal: true

module ::DiscourseChatbot
  class TokenUsageLogger
    
    def self.log_usage(user_id:, model_name:, input_tokens:, output_tokens:, request_type: 'chat', **options)
      total_tokens = input_tokens + output_tokens
      
      # Рассчитываем стоимость
      cost_data = TokenCostCalculator.calculate_cost(model_name, input_tokens, output_tokens, request_type)
      
      # Создаем запись об использовании
      usage_record = TokenUsage.create!(
        user_id: user_id,
        model_name: model_name,
        request_type: request_type,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: total_tokens,
        input_cost: cost_data[:input_cost],
        output_cost: cost_data[:output_cost],
        total_cost: cost_data[:total_cost],
        currency: 'USD',
        topic_id: options[:topic_id],
        post_id: options[:post_id],
        chat_message_id: options[:chat_message_id],
        metadata: options[:metadata]&.to_json
      )

      # Логируем для отладки если включено
      if SiteSetting.chatbot_enable_verbose_rails_logging != 'off'
        Rails.logger.info("ChatBot Token Usage: User #{user_id}, Model #{model_name}, " \
                         "Tokens: #{total_tokens} (#{input_tokens}/#{output_tokens}), " \
                         "Cost: $#{cost_data[:total_cost].round(6)}")
      end

      usage_record
    rescue => e
      Rails.logger.error("Failed to log token usage: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end

    def self.log_chat_usage(user_id:, model_name:, input_tokens:, output_tokens:, topic_id: nil, post_id: nil)
      log_usage(
        user_id: user_id,
        model_name: model_name,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        request_type: 'chat',
        topic_id: topic_id,
        post_id: post_id
      )
    end

    def self.log_embedding_usage(user_id:, model_name:, tokens:, post_id: nil, topic_id: nil)
      log_usage(
        user_id: user_id,
        model_name: model_name,
        input_tokens: tokens,
        output_tokens: 0,
        request_type: 'embedding',
        topic_id: topic_id,
        post_id: post_id
      )
    end

    def self.log_vision_usage(user_id:, model_name:, input_tokens:, output_tokens:, topic_id: nil, post_id: nil)
      log_usage(
        user_id: user_id,
        model_name: model_name,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        request_type: 'vision',
        topic_id: topic_id,
        post_id: post_id
      )
    end

    def self.log_image_generation_usage(user_id:, model_name:, images_count: 1, topic_id: nil, post_id: nil)
      log_usage(
        user_id: user_id,
        model_name: model_name,
        input_tokens: images_count, # Для изображений считаем количество изображений
        output_tokens: 0,
        request_type: 'image_generation',
        topic_id: topic_id,
        post_id: post_id
      )
    end

    def self.get_user_usage_summary(user_id, period = nil)
      scope = TokenUsage.by_user(user_id)
      scope = scope.send(period) if period && TokenUsage.respond_to?(period)
      
      {
        total_requests: scope.count,
        total_tokens: scope.sum(:total_tokens),
        total_cost: scope.sum(:total_cost),
        input_tokens: scope.sum(:input_tokens),
        output_tokens: scope.sum(:output_tokens),
        by_model: scope.group(:model_name).sum(:total_cost),
        by_type: scope.group(:request_type).sum(:total_cost)
      }
    end

    def self.get_system_usage_summary(period = nil)
      scope = TokenUsage.all
      scope = scope.send(period) if period && TokenUsage.respond_to?(period)
      
      {
        total_requests: scope.count,
        total_users: scope.distinct.count(:user_id),
        total_tokens: scope.sum(:total_tokens),
        total_cost: scope.sum(:total_cost),
        input_tokens: scope.sum(:input_tokens),
        output_tokens: scope.sum(:output_tokens),
        by_model: scope.group(:model_name).sum(:total_cost),
        by_type: scope.group(:request_type).sum(:total_cost),
        top_users: scope.group(:user_id).sum(:total_cost).sort_by { |_, cost| -cost }.first(10)
      }
    end

    def self.cleanup_old_records(older_than_days = 90)
      cutoff_date = older_than_days.days.ago
      deleted_count = TokenUsage.where('created_at < ?', cutoff_date).delete_all
      Rails.logger.info("Cleaned up #{deleted_count} old token usage records (older than #{older_than_days} days)")
      deleted_count
    end
  end
end

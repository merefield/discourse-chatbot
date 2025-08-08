# frozen_string_literal: true

module ::DiscourseChatbot
  class ChatbotTokenStatsController < ::ApplicationController
    requires_plugin ::DiscourseChatbot::PLUGIN_NAME
    
    before_action :ensure_staff
    before_action :ensure_chatbot_enabled

    def index
      # Возвращаем основную страницу со статистикой
      render json: success_json
    end

    def usage_stats
      period = params[:period] || 'this_month'
      
      # Системная статистика
      system_stats = TokenUsageLogger.get_system_usage_summary(period)
      
      # Статистика по дням для графика
      start_date = case period
                   when 'today'
                     Date.current
                   when 'this_week'
                     1.week.ago.to_date
                   when 'this_month'
                     1.month.ago.to_date
                   else
                     1.month.ago.to_date
                   end
      
      daily_stats = TokenUsage.daily_usage_for_period(start_date, Date.current)
      
      # Топ пользователей
      top_users_data = TokenUsage.joins(:user)
                                 .where(created_at: start_date.beginning_of_day..Date.current.end_of_day)
                                 .group('users.username', :user_id)
                                 .sum(:total_cost, :total_tokens)
                                 .map { |key, values| 
                                   {
                                     username: key[0],
                                     user_id: key[1],
                                     total_cost: values.is_a?(Hash) ? values.values.first : values,
                                     total_tokens: values.is_a?(Hash) ? values.values.last : 0
                                   }
                                 }
                                 .sort_by { |user| -user[:total_cost] }
                                 .first(10)

      render json: {
        system_stats: system_stats,
        daily_stats: format_daily_stats(daily_stats),
        top_users: top_users_data,
        period: period
      }
    end

    def model_stats
      period = params[:period] || 'this_month'
      
      scope = TokenUsage.all
      scope = scope.send(period) if period && TokenUsage.respond_to?(period)
      
      model_stats = scope.group(:model_name)
                         .group(:request_type)
                         .sum(:total_cost, :total_tokens)

      # Форматируем данные для графиков
      formatted_stats = {}
      model_stats.each do |(model, type), values|
        formatted_stats[model] ||= {}
        formatted_stats[model][type] = {
          cost: values.is_a?(Hash) ? values.values.first : values,
          tokens: values.is_a?(Hash) ? values.values.last : 0
        }
      end

      # Добавляем информацию о ценах на модели
      pricing_info = {}
      TokenCostCalculator.supported_models.each do |model|
        pricing_info[model] = TokenCostCalculator.get_model_pricing(model)
      end

      render json: {
        model_stats: formatted_stats,
        pricing_info: pricing_info,
        period: period
      }
    end

    def user_stats
      user_id = params[:user_id]&.to_i
      period = params[:period] || 'this_month'
      
      if user_id
        user_stats = TokenUsageLogger.get_user_usage_summary(user_id, period)
        user = User.find_by(id: user_id)
        
        render json: {
          user: user&.slice(:id, :username, :name),
          stats: user_stats,
          period: period
        }
      else
        # Список всех пользователей с общей статистикой
        users_stats = TokenUsage.joins(:user)
                                .group('users.username', :user_id)
                                .sum(:total_cost, :total_tokens)
                                .map { |key, values| 
                                  {
                                    username: key[0],
                                    user_id: key[1],
                                    total_cost: values.is_a?(Hash) ? values.values.first : values,
                                    total_tokens: values.is_a?(Hash) ? values.values.last : 0
                                  }
                                }
                                .sort_by { |user| -user[:total_cost] }

        render json: {
          users: users_stats,
          period: period
        }
      end
    end

    def export_data
      format = params[:format] || 'csv'
      period = params[:period] || 'this_month'
      
      scope = TokenUsage.includes(:user)
      scope = scope.send(period) if period && TokenUsage.respond_to?(period)
      
      case format
      when 'csv'
        csv_data = generate_csv(scope)
        send_data csv_data, filename: "chatbot_usage_#{period}_#{Date.current}.csv", type: 'text/csv'
      when 'json'
        json_data = scope.as_json(include: { user: { only: [:username, :name] } })
        send_data json_data.to_json, filename: "chatbot_usage_#{period}_#{Date.current}.json", type: 'application/json'
      else
        render json: { error: 'Unsupported format' }, status: 400
      end
    end

    def cleanup_old_data
      days = params[:days]&.to_i || 90
      
      if days < 30
        render json: { error: 'Cannot cleanup data newer than 30 days' }, status: 400
        return
      end

      deleted_count = TokenUsageLogger.cleanup_old_records(days)
      
      render json: {
        success: true,
        deleted_count: deleted_count,
        message: "Deleted #{deleted_count} records older than #{days} days"
      }
    end

    private

    def ensure_chatbot_enabled
      raise Discourse::NotFound unless SiteSetting.chatbot_enabled
    end

    def format_daily_stats(daily_stats)
      formatted = {}
      daily_stats.each do |(date, model), values|
        formatted[date] ||= {}
        formatted[date][model] = {
          cost: values.is_a?(Hash) ? values.values.first : values,
          tokens: values.is_a?(Hash) ? values.values.last : 0
        }
      end
      formatted
    end

    def generate_csv(scope)
      require 'csv'
      
      CSV.generate do |csv|
        csv << ['Date', 'Username', 'Model', 'Request Type', 'Input Tokens', 'Output Tokens', 'Total Tokens', 'Total Cost (USD)']
        
        scope.find_each do |usage|
          csv << [
            usage.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            usage.user.username,
            usage.model_name,
            usage.request_type,
            usage.input_tokens,
            usage.output_tokens,
            usage.total_tokens,
            usage.total_cost.to_f
          ]
        end
      end
    end
  end
end

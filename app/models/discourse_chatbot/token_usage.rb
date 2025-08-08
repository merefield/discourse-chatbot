# frozen_string_literal: true

module ::DiscourseChatbot
  class TokenUsage < ActiveRecord::Base
    self.table_name = 'chatbot_token_usage'

    belongs_to :user
    belongs_to :topic, optional: true
    belongs_to :post, optional: true

    validates :user_id, presence: true
    validates :model_name, presence: true
    validates :request_type, presence: true, inclusion: { in: %w[chat embedding vision image_generation] }
    validates :total_tokens, presence: true, numericality: { greater_than: 0 }
    validates :total_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }

    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :by_model, ->(model) { where(model_name: model) }
    scope :by_type, ->(type) { where(request_type: type) }
    scope :in_period, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
    scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }
    scope :this_month, -> { where(created_at: 1.month.ago..Time.current) }

    def self.total_cost_for_user(user_id, period = nil)
      scope = by_user(user_id)
      scope = scope.send(period) if period && respond_to?(period)
      scope.sum(:total_cost)
    end

    def self.total_tokens_for_user(user_id, period = nil)
      scope = by_user(user_id)
      scope = scope.send(period) if period && respond_to?(period)
      scope.sum(:total_tokens)
    end

    def self.usage_stats_by_model(period = nil)
      scope = all
      scope = scope.send(period) if period && respond_to?(period)
      scope.group(:model_name).sum(:total_cost, :total_tokens)
    end

    def self.daily_usage_for_period(start_date, end_date)
      in_period(start_date, end_date)
        .group("DATE(created_at)")
        .group(:model_name)
        .sum(:total_cost, :total_tokens)
    end
  end
end

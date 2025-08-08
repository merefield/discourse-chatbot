# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::TokenUsageLogger do
  let(:user) { Fabricate(:user) }
  let(:model_name) { 'gpt-4o-mini' }

  before do
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_enable_token_usage_tracking = true
  end

  describe '.log_chat_usage' do
    it 'creates a token usage record with correct data' do
      expect {
        described_class.log_chat_usage(
          user_id: user.id,
          model_name: model_name,
          input_tokens: 100,
          output_tokens: 50
        )
      }.to change { ::DiscourseChatbot::TokenUsage.count }.by(1)

      usage = ::DiscourseChatbot::TokenUsage.last
      expect(usage.user_id).to eq(user.id)
      expect(usage.model_name).to eq(model_name)
      expect(usage.request_type).to eq('chat')
      expect(usage.input_tokens).to eq(100)
      expect(usage.output_tokens).to eq(50)
      expect(usage.total_tokens).to eq(150)
      expect(usage.total_cost).to be > 0
    end
  end

  describe '.log_embedding_usage' do
    it 'creates an embedding usage record' do
      expect {
        described_class.log_embedding_usage(
          user_id: user.id,
          model_name: 'text-embedding-ada-002',
          tokens: 200
        )
      }.to change { ::DiscourseChatbot::TokenUsage.count }.by(1)

      usage = ::DiscourseChatbot::TokenUsage.last
      expect(usage.request_type).to eq('embedding')
      expect(usage.input_tokens).to eq(200)
      expect(usage.output_tokens).to eq(0)
    end
  end

  describe '.get_user_usage_summary' do
    before do
      described_class.log_chat_usage(
        user_id: user.id,
        model_name: model_name,
        input_tokens: 100,
        output_tokens: 50
      )
      described_class.log_chat_usage(
        user_id: user.id,
        model_name: model_name,
        input_tokens: 200,
        output_tokens: 100
      )
    end

    it 'returns correct summary data' do
      summary = described_class.get_user_usage_summary(user.id)
      
      expect(summary[:total_requests]).to eq(2)
      expect(summary[:total_tokens]).to eq(450) # (100+50) + (200+100)
      expect(summary[:total_cost]).to be > 0
      expect(summary[:input_tokens]).to eq(300)
      expect(summary[:output_tokens]).to eq(150)
    end
  end

  describe '.cleanup_old_records' do
    before do
      # Create old record
      old_usage = ::DiscourseChatbot::TokenUsage.create!(
        user_id: user.id,
        model_name: model_name,
        request_type: 'chat',
        total_tokens: 100,
        total_cost: 0.01,
        created_at: 100.days.ago
      )

      # Create new record
      new_usage = ::DiscourseChatbot::TokenUsage.create!(
        user_id: user.id,
        model_name: model_name,
        request_type: 'chat',
        total_tokens: 100,
        total_cost: 0.01,
        created_at: 10.days.ago
      )
    end

    it 'deletes old records but keeps new ones' do
      expect {
        described_class.cleanup_old_records(90)
      }.to change { ::DiscourseChatbot::TokenUsage.count }.by(-1)
    end
  end
end

describe ::DiscourseChatbot::TokenCostCalculator do
  describe '.calculate_cost' do
    it 'calculates cost correctly for chat models' do
      result = described_class.calculate_cost('gpt-4o-mini', 1000, 500, 'chat')
      
      expect(result[:input_cost]).to eq(0.00015) # 1000/1000 * 0.00015
      expect(result[:output_cost]).to eq(0.0003) # 500/1000 * 0.0006
      expect(result[:total_cost]).to eq(0.00045)
    end

    it 'calculates cost correctly for embedding models' do
      result = described_class.calculate_cost('text-embedding-ada-002', 1000, 0, 'embedding')
      
      expect(result[:input_cost]).to eq(0.0001) # 1000/1000 * 0.0001
      expect(result[:output_cost]).to eq(0.0)
      expect(result[:total_cost]).to eq(0.0001)
    end

    it 'returns zero cost for unknown models' do
      result = described_class.calculate_cost('unknown-model', 1000, 500)
      
      expect(result[:total_cost]).to eq(0.0)
    end
  end

  describe '.get_model_pricing' do
    it 'returns pricing for known models' do
      pricing = described_class.get_model_pricing('gpt-4o-mini')
      
      expect(pricing[:input]).to eq(0.00015)
      expect(pricing[:output]).to eq(0.0006)
    end

    it 'returns nil for unknown models' do
      pricing = described_class.get_model_pricing('unknown-model')
      
      expect(pricing).to be_nil
    end
  end
end

# frozen_string_literal: true

module ::DiscourseChatbot
  class TokenCostCalculator
    
    # Стоимость токенов для различных моделей (в долларах за 1000 токенов)
    # Данные актуальны на август 2025, могут изменяться
    MODEL_PRICING = {
      # GPT-4 series
      'gpt-4' => { input: 0.03, output: 0.06 },
      'gpt-4-turbo' => { input: 0.01, output: 0.03 },
      'gpt-4o' => { input: 0.005, output: 0.015 },
      'gpt-4o-mini' => { input: 0.00015, output: 0.0006 },
      'gpt-4.1' => { input: 0.004, output: 0.012 },
      'gpt-4.1-mini' => { input: 0.0001, output: 0.0004 },
      'gpt-4.1-nano' => { input: 0.00005, output: 0.0002 },
      
      # GPT-5 series (предполагаемые цены)
      'gpt-5' => { input: 0.002, output: 0.008 },
      'gpt-5-mini' => { input: 0.00008, output: 0.0003 },
      'gpt-5-nano' => { input: 0.00003, output: 0.00012 },
      
      # O series (reasoning models)
      'o1' => { input: 0.015, output: 0.06 },
      'o1-mini' => { input: 0.003, output: 0.012 },
      'o3' => { input: 0.02, output: 0.08 },
      'o3-mini' => { input: 0.004, output: 0.016 },
      'o4-mini' => { input: 0.002, output: 0.008 },
      
      # Embedding models
      'text-embedding-ada-002' => { input: 0.0001, output: 0.0 },
      'text-embedding-3-small' => { input: 0.00002, output: 0.0 },
      
      # Image generation models (per image, not per token)
      'dall-e-3' => { input: 0.04, output: 0.0 }, # за изображение 1024x1024
      'gpt-image-1' => { input: 0.02, output: 0.0 }
    }.freeze

    def self.calculate_cost(model_name, input_tokens, output_tokens, request_type = 'chat')
      model_name = normalize_model_name(model_name)
      pricing = MODEL_PRICING[model_name]
      
      return { input_cost: 0.0, output_cost: 0.0, total_cost: 0.0 } unless pricing
      
      case request_type
      when 'image_generation'
        # Для генерации изображений считаем по количеству изображений, а не токенов
        images_count = input_tokens > 0 ? input_tokens : 1
        total_cost = pricing[:input] * images_count
        { input_cost: total_cost, output_cost: 0.0, total_cost: total_cost }
      when 'embedding'
        # Для эмбеддингов обычно только input токены
        input_cost = (input_tokens / 1000.0) * pricing[:input]
        { input_cost: input_cost, output_cost: 0.0, total_cost: input_cost }
      else
        # Для обычных чат-запросов
        input_cost = (input_tokens / 1000.0) * pricing[:input]
        output_cost = (output_tokens / 1000.0) * pricing[:output]
        total_cost = input_cost + output_cost
        { input_cost: input_cost, output_cost: output_cost, total_cost: total_cost }
      end
    end

    def self.get_model_pricing(model_name)
      model_name = normalize_model_name(model_name)
      MODEL_PRICING[model_name]
    end

    def self.supported_models
      MODEL_PRICING.keys
    end

    def self.estimate_cost_for_text(model_name, text, is_input = true)
      # Приблизительная оценка: 1 токен ≈ 4 символа для английского текста
      # Для более точной оценки можно использовать tiktoken gem
      estimated_tokens = (text.length / 4.0).ceil
      
      if is_input
        calculate_cost(model_name, estimated_tokens, 0)[:input_cost]
      else
        calculate_cost(model_name, 0, estimated_tokens)[:output_cost]
      end
    end

    private

    def self.normalize_model_name(model_name)
      # Убираем возможные суффиксы версий и приводим к стандартному виду
      model_name.to_s.downcase.strip
    end
  end
end

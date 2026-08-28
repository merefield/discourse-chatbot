# frozen_string_literal: true
require "digest"
require "openai"

module DiscourseChatbot
  class LlmClient
    PROVIDERS = {
      "open_ai" => {
        uri_base: OpenAI::Configuration::DEFAULT_URI_BASE,
        token_setting: :chatbot_open_ai_token,
        model_setting_prefix: "chatbot_open_ai_model",
      },
      "anthropic" => {
        uri_base: "https://api.anthropic.com/v1/",
        token_setting: :chatbot_anthropic_token,
        model_setting_prefix: "chatbot_anthropic_model",
      },
      "google_gemini" => {
        uri_base: "https://generativelanguage.googleapis.com/v1beta/openai/",
        token_setting: :chatbot_google_gemini_token,
        model_setting_prefix: "chatbot_google_gemini_model",
      },
      "x_ai" => {
        uri_base: "https://api.x.ai/v1/",
        token_setting: :chatbot_x_ai_token,
        model_setting_prefix: "chatbot_x_ai_model",
      },
    }.freeze

    class ResponsesApiError < StandardError
    end

    attr_reader :client, :model_name, :provider

    def initialize(opts)
      @provider = SiteSetting.chatbot_llm_provider
      custom_api_url = custom_uri_base(opts).presence
      @official_openai_endpoint =
        provider == "open_ai" && custom_api_url.blank? &&
          SiteSetting.chatbot_open_ai_model_custom_api_type != "azure"

      @client =
        OpenAI::Client.new(client_config(custom_api_url)) do |f|
          if SiteSetting.chatbot_enable_verbose_console_logging
            f.response :logger, Logger.new($stdout), bodies: true, headers: false
          end
          if SiteSetting.chatbot_enable_verbose_rails_logging != "off"
            case SiteSetting.chatbot_verbose_rails_logging_destination_level
            when "warn"
              f.response :logger, Rails.logger, bodies: true, headers: false, log_level: :warn
            else
              f.response :logger, Rails.logger, bodies: true, headers: false, log_level: :info
            end
          end
        end

      @model_name = get_model(opts)
      @model_reasoning_level = SiteSetting.chatbot_open_ai_model_reasoning_level
      @model_verbosity = SiteSetting.chatbot_open_ai_model_verbosity
      @prompt_cache_key = build_prompt_cache_key(opts)
    end

    def get_model(opts)
      trust_level = normalized_trust_level(opts[:trust_level])
      if SiteSetting.send("chatbot_open_ai_model_custom_#{trust_level}_trust")
        return SiteSetting.send("chatbot_open_ai_model_custom_name_#{trust_level}_trust")
      end

      model_setting = "#{PROVIDERS.fetch(provider)[:model_setting_prefix]}_#{trust_level}_trust"
      SiteSetting.public_send(model_setting)
    end

    def reasoning_model?
      REASONING_MODELS.include?(@model_name)
    end

    def responses_parameters(messages, include_reasoning_summary: false)
      parameters = { model: @model_name, input: responses_input(messages) }.merge(
        prompt_cache_parameters,
      )
      parameters[:prompt_cache_options] = { mode: "implicit" } if explicit_prompt_caching?
      reasoning_output_tokens = SiteSetting.chatbot_open_ai_max_reasoning_output_tokens
      parameters[:max_output_tokens] = reasoning_output_tokens if reasoning_output_tokens.positive?

      reasoning = {}
      reasoning[:effort] = @model_reasoning_level if @model_reasoning_level.present?
      reasoning[:summary] = "auto" if include_reasoning_summary
      parameters[:reasoning] = reasoning if reasoning.present?

      text = {}
      text[:verbosity] = @model_verbosity if @model_verbosity.present?
      parameters[:text] = text if text.present?

      parameters
    end

    def prompt_cache_parameters
      @prompt_cache_key ? { prompt_cache_key: @prompt_cache_key } : {}
    end

    def chat_completions_parameters(messages)
      { model: @model_name, messages: chat_completions_messages(messages) }.merge(
        prompt_cache_parameters,
      )
    end

    def chat_completions_generation_parameters
      parameters = {
        temperature: SiteSetting.chatbot_request_temperature / 100.0,
        top_p: SiteSetting.chatbot_request_top_p / 100.0,
      }

      if %w[open_ai x_ai].include?(provider)
        parameters.merge!(
          frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
          presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0,
        )
      end

      parameters.clear if provider == "google_gemini"
      parameters
    end

    def explicit_prompt_caching?
      @official_openai_endpoint && @model_name.match?(/\Agpt-5\.6(?:-|\z)/)
    end

    def chat_completions_messages(messages)
      messages =
        messages.map do |message|
          message = message.deep_symbolize_keys
          message[:role] = "system" if provider == "google_gemini" && message[:role] == "developer"
          message
        end

      return messages if !explicit_prompt_caching?

      messages.map do |message|
        next message.except(:prompt_cache_breakpoint) if !message[:prompt_cache_breakpoint]

        message.except(:prompt_cache_breakpoint).merge(
          content: [
            {
              type: "text",
              text: message[:content].to_s,
              prompt_cache_breakpoint: {
                mode: "explicit",
              },
            },
          ],
        )
      end
    end

    def completion_token_limit_parameters
      completion_tokens = SiteSetting.chatbot_max_response_tokens
      return {} if !completion_tokens.positive?

      { max_completion_tokens: completion_tokens }
    end

    def responses_input(messages)
      messages.flat_map { |message| responses_message(message) }.compact
    end

    def responses_message(message)
      message = message.with_indifferent_access
      role = message[:role]

      if message[:type].present?
        message.deep_symbolize_keys
      elsif role == "tool"
        {
          type: "function_call_output",
          call_id: message[:tool_call_id],
          output: message[:content].to_s,
        }
      elsif message[:tool_calls].present?
        Array(message[:tool_calls]).map do |tool_call|
          tool_call = tool_call.with_indifferent_access
          function_payload = tool_call[:function].with_indifferent_access
          {
            type: "function_call",
            call_id: tool_call[:id],
            name: function_payload[:name],
            arguments: function_payload[:arguments].to_s,
          }
        end
      else
        content = {
          type: role == "assistant" ? "output_text" : "input_text",
          text: message[:content].to_s,
        }
        if message[:prompt_cache_breakpoint] && explicit_prompt_caching?
          content[:prompt_cache_breakpoint] = { mode: "explicit" }
        end

        { role: %w[developer system].include?(role) ? "developer" : role, content: [content] }
      end
    end

    def responses_tools(tools)
      return nil if tools.blank?

      tools.map do |tool|
        {
          type: "function",
          name: tool["name"],
          description: tool["description"],
          parameters: tool["parameters"],
        }
      end
    end

    def normalize_responses_response(response)
      output_items = Array(response["output"])
      validate_responses_response!(response)
      message_text = extract_responses_text(response)
      message_returned = output_items.any? { |item| item["type"] == "message" }

      tool_calls =
        output_items
          .select { |item| item["type"] == "function_call" }
          .map do |item|
            {
              "id" => item["call_id"] || item["id"],
              "type" => "function",
              "function" => {
                "name" => item["name"],
                "arguments" => item["arguments"].to_s,
              },
            }
          end

      if tool_calls.blank? && (message_returned || output_items.blank?)
        validate_visible_responses_message!(response, message_text)
      end

      finish_reason =
        if response["status"] == "incomplete"
          "length"
        elsif tool_calls.present?
          "tool_calls"
        elsif message_returned
          "stop"
        end

      {
        "choices" => [
          {
            "finish_reason" => finish_reason,
            "message" => {
              "content" => message_text,
              "tool_calls" => tool_calls.presence,
            },
          },
        ],
        "response_output" => output_items,
        "usage" => response["usage"],
      }
    end

    def responses_text(response)
      validate_responses_response!(response)
      text = extract_responses_text(response)
      validate_visible_responses_message!(response, text)

      if response["status"] == "incomplete" && text.blank?
        raise Bot::TokenBudgetError,
              "OpenAI Responses API exhausted chatbot_open_ai_max_reasoning_output_tokens before producing visible output"
      end

      if response["status"] == "incomplete"
        Rails.logger.warn("Chatbot: Returning a partial response after reaching its token limit")
      end

      text
    end

    def validate_visible_responses_message!(response, text)
      return if response["status"] == "incomplete" || text.present?

      raise ResponsesApiError, "OpenAI Responses API completed without visible message content"
    end

    def extract_responses_text(response)
      Array(response["output"])
        .select { |item| item["type"] == "message" }
        .flat_map { |item| Array(item["content"]) }
        .filter_map do |content|
          case content["type"]
          when "output_text"
            content["text"]
          when "refusal"
            content["refusal"]
          end
        end
        .join
    end

    def validate_responses_response!(response)
      if response["error"].present?
        error = response["error"]
        message = error.respond_to?(:[]) ? error["message"] || error[:message] : error.to_s
        raise ResponsesApiError, "OpenAI Responses API error: #{message}"
      end

      status = response["status"]
      return if status.blank? || status == "completed"

      if status == "incomplete"
        reason = response.dig("incomplete_details", "reason") || "unknown reason"
        return if reason == "max_output_tokens"

        raise ResponsesApiError, "OpenAI Responses API response was incomplete: #{reason}"
      end

      raise ResponsesApiError, "OpenAI Responses API returned unexpected status: #{status}"
    end

    private

    def client_config(custom_api_url)
      config = {
        access_token: SiteSetting.public_send(PROVIDERS.fetch(provider)[:token_setting]),
        uri_base: custom_api_url || PROVIDERS.fetch(provider)[:uri_base],
        log_errors: SiteSetting.chatbot_enable_verbose_rails_logging != "off",
      }

      if provider == "open_ai" && SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
        config[:api_type] = :azure
        config[:api_version] = SiteSetting.chatbot_open_ai_model_custom_api_version
      end

      config
    end

    def normalized_trust_level(trust_level)
      TRUST_LEVELS.include?(trust_level) ? trust_level : TRUST_LEVELS.first
    end

    def custom_uri_base(opts)
      trust_level = normalized_trust_level(opts[:trust_level])
      SiteSetting.send("chatbot_open_ai_model_custom_url_#{trust_level}_trust")
    end

    def build_prompt_cache_key(opts)
      return if !@official_openai_endpoint || opts[:topic_or_channel_id].blank?

      context = [
        Discourse.current_hostname,
        opts[:type],
        opts[:topic_or_channel_id],
        opts[:thread_id] || "root",
        @model_name,
      ].join(":")
      "discourse-chatbot:#{Digest::SHA256.hexdigest(context).first(40)}"
    end
  end
end

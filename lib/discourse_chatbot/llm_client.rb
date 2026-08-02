# frozen_string_literal: true
require "openai"

module DiscourseChatbot
  class LlmClient
    class ResponsesApiError < StandardError
    end

    attr_reader :client, :model_name

    def initialize(opts)
      ::OpenAI.configure do |config|
        config.access_token = SiteSetting.chatbot_open_ai_token

        case opts[:trust_level]
        when TRUST_LEVELS[0], TRUST_LEVELS[1], TRUST_LEVELS[2]
          if SiteSetting.send(
               "chatbot_open_ai_model_custom_url_" + opts[:trust_level] + "_trust",
             ).present?
            config.uri_base =
              SiteSetting.send("chatbot_open_ai_model_custom_url_" + opts[:trust_level] + "_trust")
          end
        else
          if SiteSetting.chatbot_open_ai_model_custom_url_low_trust.present?
            config.uri_base = SiteSetting.chatbot_open_ai_model_custom_url_low_trust
          end
        end

        if SiteSetting.chatbot_open_ai_model_custom_api_type == "azure"
          config.api_type = :azure
          config.api_version = SiteSetting.chatbot_open_ai_model_custom_api_version
        end
        config.log_errors = true if SiteSetting.chatbot_enable_verbose_rails_logging
      end

      @client =
        OpenAI::Client.new do |f|
          if SiteSetting.chatbot_enable_verbose_console_logging
            f.response :logger, Logger.new($stdout), bodies: true
          end
          if SiteSetting.chatbot_enable_verbose_rails_logging != "off"
            case SiteSetting.chatbot_verbose_rails_logging_destination_level
            when "warn"
              f.response :logger, Rails.logger, bodies: true, log_level: :warn
            else
              f.response :logger, Rails.logger, bodies: true, log_level: :info
            end
          end
        end

      @model_name = get_model(opts)
      @model_reasoning_level = SiteSetting.chatbot_open_ai_model_reasoning_level
      @model_verbosity = SiteSetting.chatbot_open_ai_model_verbosity
    end

    def get_model(opts)
      case opts[:trust_level]
      when TRUST_LEVELS[0], TRUST_LEVELS[1], TRUST_LEVELS[2]
        if SiteSetting.send("chatbot_open_ai_model_custom_" + opts[:trust_level] + "_trust")
          SiteSetting.send("chatbot_open_ai_model_custom_name_" + opts[:trust_level] + "_trust")
        else
          SiteSetting.send("chatbot_open_ai_model_" + opts[:trust_level] + "_trust")
        end
      else
        if SiteSetting.chatbot_open_ai_model_custom_low_trust
          SiteSetting.chatbot_open_ai_model_custom_name_low_trust
        else
          SiteSetting.chatbot_open_ai_model_low_trust
        end
      end
    end

    def reasoning_model?
      REASONING_MODELS.include?(@model_name)
    end

    def responses_parameters(messages, include_reasoning_summary: false)
      parameters = { model: @model_name, input: responses_input(messages) }
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
          function = tool_call[:function].with_indifferent_access
          {
            type: "function_call",
            call_id: tool_call[:id],
            name: function[:name],
            arguments: function[:arguments].to_s,
          }
        end
      else
        {
          role: %w[developer system].include?(role) ? "developer" : role,
          content: [
            {
              type: role == "assistant" ? "output_text" : "input_text",
              text: message[:content].to_s,
            },
          ],
        }
      end
    end

    def responses_tools(functions)
      return nil if functions.blank?

      functions.map do |tool|
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
  end
end

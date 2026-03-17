# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot
  class OpenAIBotBase < Bot
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
      @total_tokens = 0
    end

    def get_response(prompt, opts)
      raise "Overwrite me!"
    end

    def get_model(opts)
      if SiteSetting.chatbot_support_vision == "directly"
        SiteSetting.chatbot_open_ai_vision_model
      else
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
    end

    def reasoning_model?
      REASONING_MODELS.include?(@model_name)
    end

    def responses_parameters(messages)
      parameters = {
        model: @model_name,
        input: responses_input(messages),
        max_output_tokens: SiteSetting.chatbot_max_response_tokens,
      }

      reasoning = {}
      reasoning[:effort] = @model_reasoning_level if @model_reasoning_level.present?
      parameters[:reasoning] = reasoning if reasoning.present?

      text = {}
      text[:verbosity] = @model_verbosity if @model_verbosity.present?
      parameters[:text] = text if text.present?

      parameters
    end

    def responses_input(messages)
      messages.flat_map { |message| responses_message(message) }.compact
    end

    def responses_message(message)
      message = message.with_indifferent_access
      role = message[:role]

      if role == "tool"
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

    def responses_tools
      return nil if !defined?(@functions) || @functions.blank?

      @functions.map do |tool|
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
      message_text = extract_responses_text(response)

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

      {
        "choices" => [
          {
            "finish_reason" => tool_calls.present? ? "tool_calls" : "stop",
            "message" => {
              "content" => message_text,
              "tool_calls" => tool_calls.presence,
            },
          },
        ],
        "usage" => response["usage"],
      }
    end

    def extract_responses_text(response)
      Array(response["output"])
        .select { |item| item["type"] == "message" }
        .flat_map { |item| Array(item["content"]) }
        .select { |content| content["type"] == "output_text" }
        .map { |content| content["text"] }
        .join
    end
  end
end

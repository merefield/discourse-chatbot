# frozen_string_literal: true

module ::DiscourseChatbot
  class Bot
    ResponsesApiError = LlmClient::ResponsesApiError

    class NonRetryableError < StandardError
    end

    class TokenBudgetError < NonRetryableError
    end

    class ChainLimitError < NonRetryableError
    end

    attr_reader :client, :model_name, :total_tokens

    BUILT_IN_FUNCTIONS = %w[
      DiscourseChatbot::Functions::StockDataFunction
      DiscourseChatbot::Functions::ForumSearchFunction
      DiscourseChatbot::Functions::PaintFunction
      DiscourseChatbot::Functions::PaintEditFunction
      DiscourseChatbot::Functions::VisionFunction
      DiscourseChatbot::Functions::WikipediaFunction
      DiscourseChatbot::Functions::WebSearchFunction
      DiscourseChatbot::Functions::WebCrawlerFunction
      DiscourseChatbot::Functions::NewsFunction
      DiscourseChatbot::Functions::UserFieldFunction
      DiscourseChatbot::Functions::EscalateToStaffFunction
      DiscourseChatbot::Functions::CalculatorFunction
      DiscourseChatbot::Functions::RemainingQuotaFunction
    ]

    NOT_FORCED = "not_forced"
    FORCE_A_TOOL_VALUES = %w[force_a_tool force_a_function].freeze
    FORCE_LOCAL_SEARCH_FUNCTION = "force_local_forum_search"
    SIMPLE_LOCAL_REASONING = "simple"
    VERIFY_AND_REVISE = "verify_and_revise"
    BEST_OF_TWO = "best_of_two"
    UNCERTAINTY_GUIDED = "uncertainty_guided"
    REVIEW_TOKEN_LIMIT = 96
    JUDGE_TOKEN_LIMIT = 8

    def initialize(opts, tools = true)
      @llm_client = LlmClient.new(opts)
      @client = @llm_client.client
      @model_name = @llm_client.model_name
      @total_tokens = 0
      @enabled_tool_names = configured_tool_names(opts[:trust_level])
      if tools
        merge_functions(opts)
      else
        @functions = []
        @tools = nil
        @func_mapping = {}
        @chat_history = []
      end
    end

    def tool_enabled?(tool_name)
      @enabled_tool_names.include?(tool_name)
    end

    def inner_thoughts
      Array(@initial_inner_thoughts) + Array(@inner_thoughts)
    end

    def ask(opts)
      content =
        if opts[:type] == POST
          Post::PostPromptUtils.create_prompt(opts)
        else
          Message::MessagePromptUtils.create_prompt(opts)
        end

      get_response(content, opts)
    ensure
      QuotaManager.new.consume(opts[:user_id], total_tokens)
    end

    def reasoning_model?
      @llm_client.reasoning_model?
    end

    def responses_parameters(messages, include_reasoning_summary: false)
      @llm_client.responses_parameters(
        messages,
        include_reasoning_summary: include_reasoning_summary,
      )
    end

    def responses_tools
      @llm_client.responses_tools(@functions)
    end

    def normalize_responses_response(response)
      @llm_client.normalize_responses_response(response)
    end

    def responses_text(response)
      @llm_client.responses_text(response)
    end

    def completion_token_limit_parameters
      @llm_client.completion_token_limit_parameters
    end

    def ensure_chain_token_budget!
      chain_tokens = SiteSetting.chatbot_open_ai_max_chain_tokens
      return if !chain_tokens.positive? || @total_tokens < chain_tokens

      raise TokenBudgetError,
            "OpenAI response exceeded the configured chatbot_open_ai_max_chain_tokens budget"
    end

    def get_response(prompt, opts)
      private_discussion = opts[:private] || false

      if private_discussion
        system_message = {
          role: "developer",
          content: I18n.t("chatbot.prompt.system.rag.private", current_date_time: DateTime.current),
        }

        system_message_suffix = get_system_message_suffix(opts)
        system_message[:content] += "  " + system_message_suffix if system_message_suffix.present?
      else
        system_message = {
          role: "developer",
          content: I18n.t("chatbot.prompt.system.rag.open", current_date_time: DateTime.current),
        }
      end

      if tool_enabled?("user_information")
        prompt << system_message
      else
        prompt.unshift(system_message)
      end

      @initial_inner_thoughts = Array(opts[:initial_inner_thoughts]).deep_dup
      @inner_thoughts = []
      @responses_context = []
      @posts_ids_found = []
      @topic_ids_found = []
      @non_post_urls_found = []
      @trusted_url_provenance_collected = false

      @chat_history += prompt

      res = generate_response(opts)

      {
        reply: res["choices"][0]["message"]["content"],
        inner_thoughts: inner_thoughts,
        total_tokens: @total_tokens,
      }
    end

    def has_empty_user_fields?(opts)
      UserField
        .where(editable: true)
        .order(:id)
        .each do |user_field|
          user_field_type = user_field.field_type_enum
          next if %w[dropdown confirm text].exclude?(user_field_type)
          if !::UserCustomField.where(
               user_id: opts[:user_id],
               name: "user_field_#{UserField.find_by(name: user_field.name).id}",
             ).exists? ||
               ::UserCustomField
                 .where(
                   user_id: opts[:user_id],
                   name: "user_field_#{UserField.find_by(name: user_field.name).id}",
                 )
                 .first
                 .value
                 .blank?
            return true
          end
        end
      false
    end

    def get_system_message_suffix(opts)
      system_message_suffixes = []

      if tool_enabled?("user_information") && has_empty_user_fields?(opts)
        user_field_suffixes = []
        UserField
          .where(editable: true)
          .order(:id)
          .each do |user_field|
            user_field_options = []
            user_field_id = user_field.id
            user_field_type = user_field.field_type_enum
            next if %w[dropdown confirm text].exclude?(user_field_type)

            if user_field_type == "dropdown"
              UserFieldOption
                .where(user_field_id: user_field_id)
                .each { |option| user_field_options << option.value }
            end
            if !::UserCustomField.where(
                 user_id: opts[:user_id],
                 name: "user_field_#{UserField.find_by(name: user_field.name).id}",
               ).exists? ||
                 ::UserCustomField
                   .where(
                     user_id: opts[:user_id],
                     name: "user_field_#{UserField.find_by(name: user_field.name).id}",
                   )
                   .first
                   .value
                   .blank?
              user_field_suffixes << case user_field_type
              when "confirm"
                I18n.t(
                  "chatbot.prompt.function.user_information.system_message.confirmation",
                  name: user_field.name,
                  description: user_field.description,
                )
              when "dropdown"
                I18n.t(
                  "chatbot.prompt.function.user_information.system_message.dropdown",
                  name: user_field.name,
                  options: user_field_options.to_sentence,
                )
              else
                I18n.t(
                  "chatbot.prompt.function.user_information.system_message.general",
                  name: user_field.name,
                  description: user_field.description,
                )
              end
            end
            break if user_field_suffixes.length > 1
          end

        if user_field_suffixes.any?
          user_field_suffix = user_field_suffixes.reverse.join("  ")
          user_field_suffix +=
            "  " +
              I18n.t("chatbot.prompt.function.user_information.system_message.closing_statement")
          system_message_suffixes << user_field_suffix
        end
      end

      if SiteSetting.chatbot_include_custom_field_prompts
        custom_field =
          ::UserCustomField.find_by(user_id: opts[:user_id], name: "chatbot_additional_prompt")
        custom_field_prompt = custom_field&.value&.strip
        system_message_suffixes << custom_field_prompt if custom_field_prompt.present?
      end

      system_message_suffixes.join("  ")
    end

    def merge_functions(opts)
      functions = []
      if tool_enabled?("calculate")
        functions << ::DiscourseChatbot::Functions::CalculatorFunction.new
      end
      if tool_enabled?("wikipedia")
        functions << ::DiscourseChatbot::Functions::WikipediaFunction.new
      end

      if opts[:private] && tool_enabled?("user_information")
        start_length = functions.length
        UserField
          .where(editable: true)
          .order(:id)
          .each do |user_field|
            user_field_type = user_field.field_type_enum
            next if %w[dropdown confirm text].exclude?(user_field_type)
            if !::UserCustomField.where(
                 user_id: opts[:user_id],
                 name: "user_field_#{UserField.find_by(name: user_field.name).id}",
               ).exists? ||
                 ::UserCustomField
                   .where(
                     user_id: opts[:user_id],
                     name: "user_field_#{UserField.find_by(name: user_field.name).id}",
                   )
                   .first
                   .value
                   .blank?
              functions << ::DiscourseChatbot::Functions::UserFieldFunction.new(
                user_field.name,
                opts[:user_id],
              )
            end
            break if functions.length > start_length + 1
          end
      end

      if tool_enabled?("remaining_bot_quota")
        functions << ::DiscourseChatbot::Functions::RemainingQuotaFunction.new
      end
      if tool_enabled?("local_forum_search") && SiteSetting.chatbot_embeddings_enabled
        functions << ::DiscourseChatbot::Functions::ForumSearchFunction.new
      end
      functions << ::DiscourseChatbot::Functions::VisionFunction.new if tool_enabled?("vision")
      if tool_enabled?("paint_picture")
        functions << ::DiscourseChatbot::Functions::PaintFunction.new
      end
      if tool_enabled?("paint_edit_picture") &&
           SiteSetting.chatbot_support_picture_creation_model.start_with?("gpt-image-")
        functions << ::DiscourseChatbot::Functions::PaintEditFunction.new
      end

      if tool_enabled?("escalate_to_staff") && opts[:private] &&
           opts[:type] == ::DiscourseChatbot::MESSAGE
        functions << ::DiscourseChatbot::Functions::EscalateToStaffFunction.new
      end
      if tool_enabled?("news") && SiteSetting.chatbot_news_api_token.present?
        functions << ::DiscourseChatbot::Functions::NewsFunction.new
      end
      if tool_enabled?("web_crawler") &&
           !(
             SiteSetting.chatbot_firecrawl_api_token.blank? &&
               SiteSetting.chatbot_jina_api_token.blank?
           )
        functions << ::DiscourseChatbot::Functions::WebCrawlerFunction.new
      end
      if tool_enabled?("web_search") &&
           !(SiteSetting.chatbot_serp_api_key.blank? && SiteSetting.chatbot_jina_api_token.blank?)
        functions << ::DiscourseChatbot::Functions::WebSearchFunction.new
      end
      if tool_enabled?("stock_data") && SiteSetting.chatbot_marketstack_key.present?
        functions << ::DiscourseChatbot::Functions::StockDataFunction.new
      end

      ::DiscourseChatbot::Function.descendants.each do |function_class|
        next if BUILT_IN_FUNCTIONS.include?(function_class.to_s)

        begin
          next if function_class.respond_to?(:available?) && !function_class.available?(opts)

          functions << function_class.new
        rescue StandardError => error
          Rails.logger.warn(
            "Chatbot: unable to load extension function #{function_class}: #{error.class}: #{error.message}",
          )
        end
      end

      @functions = parse_functions(functions)
      @tools = @functions.map { |func| { type: "function", function: func } }.presence
      @func_mapping = create_func_mapping(functions)
      @chat_history = []
    end

    def configured_tool_names(trust_level)
      trust_level = TRUST_LEVELS.first if TRUST_LEVELS.exclude?(trust_level)
      SiteSetting.send("chatbot_tools_#{trust_level}_trust").split("|")
    end

    def parse_functions(functions)
      return nil if functions.nil?
      functions.map { |func| ::DiscourseChatbot::Functions::Parser.func_to_json(func) }
    end

    def create_func_mapping(functions)
      return {} if functions.nil?
      functions.index_by(&:name)
    end

    def create_chat_completion(
      messages,
      use_functions = true,
      iteration = 1,
      parameter_overrides: {},
      include_logprobs: nil
    )
      begin
        ::DiscourseChatbot.progress_debug_message <<~EOS
          I called the LLM to help me
          ------------------------------
          value of messages is: #{JSON.pretty_generate(messages)}
          +++++++++++++++++++++++++++++++
        EOS

        if reasoning_model?
          parameters =
            responses_parameters(
              messages,
              include_reasoning_summary: SiteSetting.chatbot_open_ai_include_reasoning_summaries,
            )

          if use_functions && @tools
            parameters[:tools] = responses_tools
            if iteration == 1
              if FORCE_A_TOOL_VALUES.include?(SiteSetting.chatbot_tool_choice_first_iteration)
                parameters[:tool_choice] = "required"
              elsif SiteSetting.chatbot_tool_choice_first_iteration == FORCE_LOCAL_SEARCH_FUNCTION
                parameters[:tool_choice] = { type: "function", name: "local_forum_search" }
              end
            end
          end

          raw_response = @client.responses.create(parameters: parameters)
          token_usage = raw_response.dig("usage", "total_tokens")
          @total_tokens += token_usage.to_i
          res = normalize_responses_response(raw_response)
        else
          parameters = {
            model: @model_name,
            messages: messages,
            temperature: SiteSetting.chatbot_request_temperature / 100.0,
            top_p: SiteSetting.chatbot_request_top_p / 100.0,
            frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
            presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0,
          }
          parameters.merge!(completion_token_limit_parameters)
          include_logprobs = uncertainty_guided_reasoning? if include_logprobs.nil?
          parameters[:logprobs] = true if include_logprobs && @logprobs_supported != false
          parameters.merge!(parameter_overrides)

          if use_functions && @tools
            parameters.merge!(tools: @tools)
            if iteration == 1
              if FORCE_A_TOOL_VALUES.include?(SiteSetting.chatbot_tool_choice_first_iteration)
                parameters.merge!(tool_choice: "required")
              elsif SiteSetting.chatbot_tool_choice_first_iteration == FORCE_LOCAL_SEARCH_FUNCTION
                parameters.merge!(
                  tool_choice: {
                    type: "function",
                    function: {
                      name: "local_forum_search",
                    },
                  },
                )
              end
            end
          end

          begin
            res = @client.chat(parameters: parameters)
          rescue => e
            raise if !parameters[:logprobs] || !unsupported_logprobs_parameter?(e)

            @logprobs_supported = false
            parameters.delete(:logprobs)
            Rails.logger.warn(
              "Chatbot: Chat Completions provider rejected logprobs; continuing without confidence data",
            )
            res = @client.chat(parameters: parameters)
          end
          token_usage = res.dig("usage", "total_tokens")
          @total_tokens += token_usage.to_i
        end

        ::DiscourseChatbot.progress_debug_message <<~EOS
          +++++++++++++++++++++++++++++++++++++++
          The llm responded with
          #{JSON.pretty_generate(res)}
          +++++++++++++++++++++++++++++++++++++++
        EOS
        res
      rescue => e
        if e.respond_to?(:response)
          status = e.response[:status]
          message = e.response[:body]["error"]["message"]
          Rails.logger.error(
            "Chatbot: There was a problem with Chat Completion: status: #{status}, message: #{message}",
          )
        end
        raise e
      end
    end

    def generate_response(opts)
      iteration = 1
      tool_call_count = 0
      url_validation_retries = 0
      max_iterations = SiteSetting.chatbot_chain_of_thought_max_iterations
      max_tool_calls = SiteSetting.chatbot_chain_of_thought_max_tool_calls
      max_url_repair_attempts = SiteSetting.chatbot_chain_of_thought_max_url_repair_attempts
      ::DiscourseChatbot.progress_debug_message <<~EOS
        ===============================
        # New Query
        -------------------------------
      EOS
      loop do
        ensure_chain_token_budget!

        if iteration > max_iterations
          raise ChainLimitError, "Chatbot response exceeded the maximum number of iterations"
        end

        ::DiscourseChatbot.progress_debug_message <<~EOS
          # Iteration: #{iteration}
          -------------------------------
        EOS
        messages = @chat_history + (reasoning_model? ? @responses_context : @inner_thoughts)
        use_functions = iteration < max_iterations
        res = create_chat_completion(messages, use_functions, iteration)
        append_responses_output(res) if reasoning_model?
        append_reasoning_summaries(res) if reasoning_model?

        if res.dig("error")
          error_text =
            "ERROR when trying to perform chat completion: #{res.dig("error", "message")}"

          Rails.logger.error("Chatbot: #{error_text}")
        end

        finish_reason = res["choices"][0]["finish_reason"]
        tools_calls = res["choices"][0]["message"]["tool_calls"]
        tool_results = []

        content = res["choices"][0]["message"]["content"]
        if finish_reason == "length" && (content.blank? || tools_calls.present?)
          raise TokenBudgetError,
                "OpenAI response reached its token limit before producing usable content"
        end

        if reasoning_model? && finish_reason.nil? && tools_calls.nil? &&
             res["response_output"].present?
          iteration += 1
          next
        end

        if %w[stop length].include?(finish_reason) && tools_calls.nil?
          if response_urls_valid?(content)
            if finish_reason == "length"
              Rails.logger.warn(
                "Chatbot: Returning a partial response after reaching its token limit",
              )
              return res
            end
            return apply_advanced_local_reasoning(res, messages, iteration, max_iterations)
          end

          url_validation_retries += 1
          if url_validation_retries > max_url_repair_attempts || iteration >= max_iterations
            raise ChainLimitError, "Chatbot response repeatedly contained unsupported URLs"
          end

          append_url_validation_feedback
        elsif finish_reason == "tool_calls" || !tools_calls.nil?
          if !use_functions
            raise ChainLimitError, "Chatbot requested a tool after tools were disabled"
          end
          raise "Chatbot returned a tool finish reason without tool calls" if tools_calls.blank?

          tool_call_count += tools_calls.length
          if tool_call_count > max_tool_calls
            raise ChainLimitError, "Chatbot response exceeded the maximum number of tool calls"
          end

          ensure_chain_token_budget!
          tool_results = handle_function_call(res, opts)
        else
          raise "Unexpected finish reason: #{finish_reason}"
        end

        if (image_content = direct_image_tool_result(tool_results))
          return({ "choices" => [{ "message" => { "content" => image_content } }] })
        end

        iteration += 1
      end
    end

    def apply_advanced_local_reasoning(res, messages, iteration, max_iterations)
      strategy = advanced_local_reasoning_strategy
      return res if strategy == SIMPLE_LOCAL_REASONING

      append_advanced_local_reasoning_outcome("strategy_started", strategy: strategy)

      case strategy
      when VERIFY_AND_REVISE
        verify_and_revise(res, messages, iteration, max_iterations)
      when BEST_OF_TWO
        choose_best_of_two(res, messages, iteration, max_iterations)
      when UNCERTAINTY_GUIDED
        uncertainty_guided_search(res, messages, iteration, max_iterations)
      else
        res
      end
    rescue => e
      append_advanced_local_reasoning_outcome("strategy_failed", strategy: strategy || "advanced")
      Rails.logger.warn(
        "Chatbot: Advanced local reasoning failed; returning the initial answer: #{e.class}: #{e.message}",
      )
      res
    end

    def verify_and_revise(res, messages, iteration, max_iterations)
      if !advanced_calls_available?(iteration, max_iterations, 2)
        append_advanced_local_reasoning_outcome("review_skipped_iteration_limit")
        return res
      end

      answer = response_content(res)
      review_messages =
        messages +
          [
            { role: "assistant", content: answer },
            {
              role: "developer",
              content: I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.review"),
            },
          ]
      review_res =
        create_advanced_local_reasoning_completion(
          review_messages,
          iteration + 1,
          token_limit: REVIEW_TOKEN_LIMIT,
        )
      review = usable_advanced_response_content(review_res)&.strip
      if review.blank?
        append_advanced_local_reasoning_outcome("review_unusable")
        return res
      end

      @inner_thoughts << { type: "advanced_local_reasoning_review", content: review }
      if review.match?(/\APASS\z/i)
        append_advanced_local_reasoning_outcome("review_passed")
        return res
      end

      findings = review[/\AREVISE:\s*(.+)\z/im, 1]&.strip
      if findings.blank?
        append_advanced_local_reasoning_outcome("review_unrecognized")
        return res
      end

      revision_messages =
        messages +
          [
            { role: "assistant", content: answer },
            {
              role: "developer",
              content:
                I18n.t(
                  "chatbot.prompt.system.rag.advanced_local_reasoning.revise",
                  findings: JSON.generate(findings),
                ),
            },
          ]
      revision_res = create_advanced_local_reasoning_completion(revision_messages, iteration + 2)
      revision = usable_advanced_response_content(revision_res)

      if revision.blank?
        append_advanced_local_reasoning_outcome("revision_unusable")
        res
      elsif !response_urls_valid?(revision)
        append_advanced_local_reasoning_outcome("revision_url_rejected")
        res
      else
        append_advanced_local_reasoning_outcome("revision_adopted")
        revision_res
      end
    end

    def uncertainty_guided_search(res, messages, iteration, max_iterations)
      confidence = response_confidence(res)
      threshold = SiteSetting.chatbot_advanced_local_reasoning_min_confidence

      if confidence && confidence >= threshold
        append_confidence_trace(confidence, "confidence_accepted")
        return res
      end

      append_confidence_trace(confidence, "confidence_not_accepted")
      choose_best_of_two(res, messages, iteration, max_iterations)
    end

    def choose_best_of_two(res, messages, iteration, max_iterations)
      if !advanced_calls_available?(iteration, max_iterations, 2)
        append_advanced_local_reasoning_outcome("comparison_skipped_iteration_limit")
        return res
      end

      alternative_messages =
        messages +
          [
            {
              role: "developer",
              content: I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.alternative"),
            },
          ]
      alternative_res =
        create_advanced_local_reasoning_completion(alternative_messages, iteration + 1)
      alternative = usable_advanced_response_content(alternative_res)
      if alternative.blank?
        append_advanced_local_reasoning_outcome("alternative_unusable")
        return res
      elsif !response_urls_valid?(alternative)
        append_advanced_local_reasoning_outcome("alternative_url_rejected")
        return res
      end

      candidates = JSON.generate(A: response_content(res), B: alternative)
      judge_messages =
        messages +
          [
            {
              role: "developer",
              content:
                I18n.t(
                  "chatbot.prompt.system.rag.advanced_local_reasoning.judge",
                  candidates: candidates,
                ),
            },
          ]
      judge_res =
        create_advanced_local_reasoning_completion(
          judge_messages,
          iteration + 2,
          token_limit: JUDGE_TOKEN_LIMIT,
        )
      selection = usable_advanced_response_content(judge_res)&.strip&.upcase
      if %w[A B].exclude?(selection)
        append_advanced_local_reasoning_outcome("judge_unusable")
        return res
      end

      @inner_thoughts << {
        type: "advanced_local_reasoning_selection",
        content:
          I18n.t(
            "chatbot.prompt.system.rag.advanced_local_reasoning.selection",
            candidate: selection,
          ),
      }
      selection == "B" ? alternative_res : res
    end

    def append_advanced_local_reasoning_outcome(key, **options)
      @inner_thoughts << {
        type: "advanced_local_reasoning_outcome",
        content:
          I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.outcomes.#{key}", **options),
      }
    end

    def create_advanced_local_reasoning_completion(messages, iteration, token_limit: nil)
      ensure_chain_token_budget!
      parameter_overrides = {}
      if token_limit
        configured_limit = SiteSetting.chatbot_max_response_tokens
        parameter_overrides[:max_completion_tokens] = (
          if configured_limit.positive?
            [configured_limit, token_limit].min
          else
            token_limit
          end
        )
      end

      create_chat_completion(
        messages,
        false,
        iteration,
        parameter_overrides: parameter_overrides,
        include_logprobs: false,
      )
    end

    def response_content(res)
      res.dig("choices", 0, "message", "content").to_s
    end

    def usable_advanced_response_content(res)
      return if res.dig("choices", 0, "finish_reason") != "stop"

      content = response_content(res)
      content.presence
    end

    def response_confidence(res)
      logprobs =
        Array(res.dig("choices", 0, "logprobs", "content")).filter_map do |token|
          value = Float(token["logprob"], exception: false)
          value if value&.finite?
        end
      return if logprobs.empty?

      Math.exp(logprobs.sum / logprobs.length) * 100
    end

    def append_confidence_trace(confidence, decision_key)
      confidence_text =
        if confidence
          "#{confidence.round(1)}%"
        else
          I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.confidence_unavailable")
        end
      @inner_thoughts << {
        type: "advanced_local_reasoning_confidence",
        content:
          I18n.t(
            "chatbot.prompt.system.rag.advanced_local_reasoning.confidence",
            confidence: confidence_text,
            decision: I18n.t("chatbot.prompt.system.rag.advanced_local_reasoning.#{decision_key}"),
          ),
      }
    end

    def advanced_calls_available?(iteration, max_iterations, required_calls)
      iteration + required_calls <= max_iterations
    end

    def advanced_local_reasoning_strategy
      return SIMPLE_LOCAL_REASONING if reasoning_model?

      SiteSetting.chatbot_advanced_local_reasoning
    end

    def uncertainty_guided_reasoning?
      advanced_local_reasoning_strategy == UNCERTAINTY_GUIDED
    end

    def unsupported_logprobs_parameter?(error)
      return false if !error.respond_to?(:response)

      response = error.response
      status = response[:status] || response["status"]
      body = response[:body] || response["body"]
      message =
        if body.is_a?(Hash)
          body.dig("error", "message") || body.dig(:error, :message)
        else
          body
        end

      [400, 422].include?(status.to_i) && message.to_s.match?(/logprobs?/i)
    end

    def append_responses_output(res)
      @responses_context.concat(
        Array(res["response_output"]).map { |output_item| output_item.deep_symbolize_keys },
      )
    end

    def append_reasoning_summaries(res)
      Array(res["response_output"]).each do |output_item|
        next if output_item["type"] != "reasoning"

        Array(output_item["summary"]).each do |summary|
          next if summary["text"].blank?

          @inner_thoughts << { type: "reasoning_summary", content: summary["text"] }
        end
      end
    end

    def append_url_validation_feedback
      feedback = { role: "developer", content: I18n.t("chatbot.prompt.system.rag.illegal_urls") }

      if reasoning_model?
        @responses_context << feedback
      else
        @inner_thoughts << feedback
      end
    end

    def direct_image_tool_result(tool_results)
      return if !tool_results.one?

      tool_result = tool_results.first
      return if %w[paint_picture paint_edit_picture].exclude?(tool_result[:name])

      content = tool_result[:content]
      return if !content.start_with?("!") || !content.end_with?(")")
      return if !content.match?(%r{(upload://)?([a-zA-Z0-9]+)(\..*)?})

      content if response_urls_valid?(content)
    end

    def handle_function_call(res, opts)
      functions_called = res["choices"][0]["message"]

      tools_called = functions_called["tool_calls"]

      # Convert the semi-JSON string to Ruby objects so we can make tests pass otherwise
      # format of tools_called is generated won't match what is expected in the tests
      # even though without it the code works fine

      ruby_object_array = []

      tools_called.each do |tool_called|
        json_str = tool_called.to_json
        ruby_objects = JSON.parse(json_str, symbolize_names: true)
        ruby_object_array << ruby_objects
      end

      # end of section of code to make tests pass

      tools_thought = { role: "assistant", content: "", tool_calls: ruby_object_array }

      @inner_thoughts << tools_thought
      tool_results = []

      tools_called.each do |function_called|
        ensure_chain_token_budget!

        func_name = function_called["function"]["name"]
        args_str = function_called["function"]["arguments"]
        tool_call_id = function_called["id"]
        tool_result = normalize_tool_result(call_function(func_name, args_str, opts))
        collect_trusted_url_provenance(tool_result)
        result = tool_result[:content].to_s
        tool_results << { name: func_name, content: result }
        @inner_thoughts << { role: "tool", tool_call_id: tool_call_id, content: result }
        if reasoning_model?
          @responses_context << {
            type: "function_call_output",
            call_id: tool_call_id,
            output: result,
          }
        end
      end
      tool_results
    end

    def normalize_tool_result(result)
      result_hash = result.with_indifferent_access if result.is_a?(Hash)
      result_hash = nil if result_hash && !result_hash.key?(:result)

      if result_hash
        {
          content: result_hash[:result],
          post_ids_found: Array(result_hash[:post_ids_found]),
          topic_ids_found: Array(result_hash[:topic_ids_found]),
          non_post_urls_found: Array(result_hash[:non_post_urls_found]),
          provenance_declared: true,
        }
      else
        {
          content: result,
          post_ids_found: [],
          topic_ids_found: [],
          non_post_urls_found: [],
          provenance_declared: false,
        }
      end
    end

    def collect_trusted_url_provenance(tool_result)
      content = tool_result[:content].to_s
      absolute_urls = extract_http_urls(content)
      relative_forum_paths = extract_relative_forum_paths(content)

      post_ids_found = tool_result[:post_ids_found]
      topic_ids_found = tool_result[:topic_ids_found]
      non_post_urls_found = tool_result[:non_post_urls_found]

      absolute_urls.each do |url|
        uri = URI.parse(url)
        if uri.host&.casecmp?(Discourse.current_hostname) && legal_forum_path?(uri.path)
          collect_forum_path_provenance(uri.path, post_ids_found, topic_ids_found)
        else
          normalized_url = normalize_url(url)
          non_post_urls_found << normalized_url if normalized_url
        end
      rescue URI::Error
        next
      end

      relative_forum_paths.each do |path|
        uri = URI.parse(path)
        if legal_forum_path?(uri.path)
          collect_forum_path_provenance(uri.path, post_ids_found, topic_ids_found)
        end
      rescue URI::Error
        next
      end

      @trusted_url_provenance_collected ||=
        tool_result[:provenance_declared] || absolute_urls.present? || relative_forum_paths.present?
      @posts_ids_found = (@posts_ids_found.to_set | post_ids_found.to_set).to_a
      @topic_ids_found = (@topic_ids_found.to_set | topic_ids_found.to_set).to_a
      normalized_non_post_urls = non_post_urls_found.filter_map { |url| normalize_url(url) }
      @non_post_urls_found = (@non_post_urls_found.to_set | normalized_non_post_urls.to_set).to_a
    end

    def collect_forum_path_provenance(path, post_ids_found, topic_ids_found)
      match = path.match(%r{\A/t/[^/]+/(\d+)(?:/(\d+))?/?\z})
      return if !match

      topic_id = match[1].to_i
      post_number = match[2]
      if post_number
        post = ::Post.find_by(topic_id: topic_id, post_number: post_number.to_i)
        if post
          post_ids_found << post.id
          topic_ids_found << post.topic_id
        end
      else
        topic_ids_found << topic_id
      end
    end

    def call_function(func_name, args_str, opts)
      begin
        token_usage = 0
        args = JSON.parse(args_str)
        ::DiscourseChatbot.progress_debug_message <<~EOS
          +++++++++++++++++++++++++++++++++++++++
          I used '#{func_name}' to help me
          args_str was '#{JSON.pretty_generate(args)}'
          opts was '#{JSON.pretty_generate(opts)}'
          +++++++++++++++++++++++++++++++++++++++
        EOS
        func = @func_mapping[func_name]
        if %w[escalate_to_staff remaining_bot_quota].include?(func_name)
          res, token_usage = func.process(args, opts).values_at(:answer, :token_usage)
        elsif ["vision"].include?(func_name)
          res, token_usage = func.process(args, opts, @client).values_at(:answer, :token_usage)
        elsif ["paint_edit_picture"].include?(func_name)
          res, token_usage = func.process(args, opts).values_at(:answer, :token_usage)
        else
          res, token_usage = func.process(args).values_at(:answer, :token_usage)
        end
        @total_tokens += token_usage.to_i
        res
      rescue => e
        Rails.logger.error(
          "Chatbot: There was a problem with local function arguments, message: #{e}",
        )
        I18n.t("chatbot.prompt.rag.call_function.error")
      end
    end

    def legal_post_urls?(res, post_ids_found, topic_ids_found)
      return true if res.blank?

      absolute_forum_urls =
        extract_http_urls(res).select do |url|
          uri = URI.parse(url)
          uri.host&.casecmp?(Discourse.current_hostname) && uri.path.include?("/t/")
        rescue URI::Error
          false
        end

      forum_paths =
        absolute_forum_urls.map { |url| URI.parse(url).path } + extract_relative_forum_paths(res)
      forum_paths.each do |path|
        match = path.match(%r{\A/t/[^/]+/(\d+)(?:/(\d+))?/?\z})
        return false if !match

        topic_id = match[1].to_i
        post_number = match[2]
        if post_number
          post = ::Post.find_by(topic_id: topic_id, post_number: post_number.to_i)
          return false if post.nil? || !post_ids_found.include?(post.id)
        elsif !topic_ids_found.include?(topic_id)
          return false
        end
      end

      true
    end

    def legal_forum_path?(path)
      path.match?(%r{\A/t/[^/]+/\d+(?:/\d+)?/?\z})
    end

    def legal_non_post_urls?(res, non_post_urls_found)
      return true if res.blank?

      normalized_allowed_urls = non_post_urls_found.filter_map { |url| normalize_url(url) }.to_set
      extract_http_urls(res)
        .reject { |url| local_forum_url?(url) }
        .all? { |url| normalized_allowed_urls.include?(normalize_url(url)) }
    end

    def extract_http_urls(content)
      content.to_s.scan(%r{\bhttps?://[^\s<]+}).map { |url| url.sub(/[\]\[)},.;:!?"']+\z/, "") }
    end

    def extract_relative_forum_paths(content)
      content
        .to_s
        .scan(%r{(?<![[:alnum:]])(/t/[^\s<]+)})
        .flatten
        .map { |path| path.sub(/[\]\[)},.;:!?"']+\z/, "") }
        .filter_map do |path|
          URI.parse(path).path
        rescue URI::Error
          nil
        end
    end

    def normalize_url(url)
      uri = URI.parse(url)
      return if !uri.is_a?(URI::HTTP) || uri.host.blank?

      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.fragment = nil
      uri.port = nil if uri.default_port == uri.port
      uri.path = "" if uri.path == "/"
      uri.path = uri.path.delete_suffix("/") if uri.path.length > 1
      uri.to_s
    rescue URI::Error
      nil
    end

    def local_forum_url?(url)
      uri = URI.parse(url)
      uri.host&.casecmp?(Discourse.current_hostname) && uri.path.start_with?("/t/")
    rescue URI::Error
      false
    end

    def response_urls_valid?(content)
      return true if !SiteSetting.chatbot_url_integrity_check || !@trusted_url_provenance_collected

      legal_post_urls?(content, @posts_ids_found, @topic_ids_found) &&
        legal_non_post_urls?(content, @non_post_urls_found)
    end

    private

    def image_url?(string)
      # Regular expression to find URLs
      url_regex = %r{\bhttps?://[^\s]+}

      # Check if the string contains more than one URL or other text
      urls = string.scan(url_regex)
      return false unless urls.length == 1 && string.strip == urls[0]

      # Proceed with the existing logic if only one URL is found
      url = urls[0]
      image_extensions = %w[.jpg .jpeg .png .gif .bmp .tiff .webp]

      uri = URI.parse(url)
      path = uri.path

      # Check the file extension
      return true if image_extensions.any? { |ext| path.downcase.end_with?(ext) }
      false
    end
  end
end

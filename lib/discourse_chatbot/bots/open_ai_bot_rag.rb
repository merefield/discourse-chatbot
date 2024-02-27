# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAiBotRag < OpenAIBotBase

    def initialize(opts)
      super
      merge_functions(opts)
    end

    def get_response(prompt, opts)
      private_discussion = opts[:private] || false

      if private_discussion
        system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.rag.private", current_date_time: DateTime.current) }
      else
        system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.rag.open", current_date_time: DateTime.current) }
      end

      prompt.unshift(system_message)

      @inner_thoughts = []

      @chat_history += prompt

      res = generate_response(opts)

      {
        reply: res["choices"][0]["message"]["content"],
        inner_thoughts: @inner_thoughts.to_s
      }
    end

    def merge_functions(opts)
      calculator_function = ::DiscourseChatbot::CalculatorFunction.new
      wikipedia_function = ::DiscourseChatbot::WikipediaFunction.new
      news_function = ::DiscourseChatbot::NewsFunction.new
      google_search_function = ::DiscourseChatbot::GoogleSearchFunction.new
      stock_data_function = ::DiscourseChatbot::StockDataFunction.new
      escalate_to_staff_function = ::DiscourseChatbot::EscalateToStaffFunction.new
      forum_search_function = nil
      user_search_from_user_location_function = nil
      user_search_from_location_function = nil
      user_distance_from_location_function = nil
      get_coords_of_location_function = nil
      get_distance_between_locations = nil
      get_user_address = nil

      if SiteSetting.chatbot_embeddings_enabled
        forum_search_function = ::DiscourseChatbot::ForumSearchFunction.new
      end

      if SiteSetting.chatbot_locations_plugin_support && defined?(Locations) == 'constant' && Locations.class == Module &&
         defined?(::Locations::UserLocation) == 'constant' && ::Locations::UserLocation.class == Class && ::Locations::UserLocation.count > 0
        user_search_from_location_function = ::DiscourseChatbot::ForumUserSearchFromLocationFunction.new
        user_search_from_user_location_function = ::DiscourseChatbot::ForumUserSearchFromUserLocationFunction.new
        get_coords_of_location_function = ::DiscourseChatbot::GetCoordsOfLocationDescriptionFunction.new
        user_distance_from_location_function = ::DiscourseChatbot::ForumUserDistanceFromLocationFunction.new
        get_distance_between_locations = ::DiscourseChatbot::GetDistanceBetweenLocationsFunction.new
        get_user_address = ::DiscourseChatbot::ForumGetUserAddressFunction.new
      end

      functions = [calculator_function, wikipedia_function]

      functions << forum_search_function if forum_search_function

      functions << user_search_from_location_function if user_search_from_location_function
      functions << user_search_from_user_location_function if user_search_from_user_location_function
      functions << get_coords_of_location_function if get_coords_of_location_function
      functions << user_distance_from_location_function if user_distance_from_location_function
      functions << get_distance_between_locations if get_distance_between_locations
      functions << get_user_address if get_user_address
      functions << escalate_to_staff_function if SiteSetting.chatbot_escalate_to_staff_function && opts[:private] && opts[:type] == ::DiscourseChatbot::MESSAGE
      functions << news_function if !SiteSetting.chatbot_news_api_token.blank?
      functions << google_search_function if !SiteSetting.chatbot_serp_api_key.blank?
      functions << stock_data_function if !SiteSetting.chatbot_marketstack_key.blank?

      @functions = parse_functions(functions)
      @func_mapping = create_func_mapping(functions)
      @chat_history = []
    end

    def parse_functions(functions)
      return nil if functions.nil?
      functions.map { |func| ::DiscourseChatbot::Parser.func_to_json(func) }
    end

    def create_func_mapping(functions)
      return {} if functions.nil?
      functions.each_with_object({}) { |func, mapping| mapping[func.name] = func }
    end

    def create_chat_completion(messages, use_functions = true)
      ::DiscourseChatbot.progress_debug_message <<~EOS
        I called the LLM to help me
        ------------------------------
        value of messages is: #{messages}
        +++++++++++++++++++++++++++++++
      EOS
      if use_functions && @functions
        res = @client.chat(
          parameters: {
            model: @model_name,
            messages: messages,
            functions: @functions
          }
        )
      else
        res = @client.chat(
          parameters: {
            model: @model_name,
            messages: messages
          }
        )
      end
      ::DiscourseChatbot.progress_debug_message <<~EOS
        +++++++++++++++++++++++++++++++++++++++
        The llm responded with
        #{res}
        +++++++++++++++++++++++++++++++++++++++
      EOS
      res
    end

    def generate_response(opts)
      iteration = 1
      ::DiscourseChatbot.progress_debug_message <<~EOS
        ===============================
        # New Query
        -------------------------------
      EOS
      loop do
        ::DiscourseChatbot.progress_debug_message <<~EOS
          # Iteration: #{iteration}
          -------------------------------
        EOS
        res = create_chat_completion(@chat_history + @inner_thoughts)

        if res.dig("error")
          error_text = "ERROR when trying to perform chat completion: #{res.dig("error", "message")}"

          Rails.logger.error("Chatbot: #{error_text}")
        end

        finish_reason = res["choices"][0]["finish_reason"]

        if finish_reason == 'stop' || @inner_thoughts.length > 5
          final_thought = final_thought_answer
          final_res = create_chat_completion(
            @chat_history + [final_thought],
            false
          )

          if final_res.dig("error")
            error_text = "ERROR when trying to perform final chat completion: #{final_res.dig("error", "message")}"

            Rails.logger.error("Chatbot: #{error_text}")
          end

          return final_res
        elsif finish_reason == 'function_call'
          handle_function_call(res, opts)
        else
          raise "Unexpected finish reason: #{finish_reason}"
        end
        iteration += 1
      end
    end

    def handle_function_call(res, opts)
      first_message = res["choices"][0]["message"]
      @inner_thoughts << first_message.to_hash
      func_name = first_message["function_call"]["name"]
      args_str = first_message["function_call"]["arguments"]
      result = call_function(func_name, args_str, opts)
      res_msg = { 'role' => 'function', 'name' => func_name, 'content' => I18n.t("chatbot.prompt.rag.handle_function_call.answer", result: result) }
      @inner_thoughts << res_msg
    end

    def call_function(func_name, args_str, opts)
      ::DiscourseChatbot.progress_debug_message <<~EOS
        +++++++++++++++++++++++++++++++++++++++
        I used '#{func_name}' to help me
        args_str was '#{args_str}'
        opts was '#{opts}'
        +++++++++++++++++++++++++++++++++++++++
      EOS
      begin
        args = JSON.parse(args_str)
        func = @func_mapping[func_name]
        if ["escalate_to_staff"].include?(func_name)
          res = func.process(args, opts)
        else
          res = func.process(args)
        end
        res
       rescue
         I18n.t("chatbot.prompt.rag.call_function.error")
      end
    end

    def final_thought_answer
      thoughts = I18n.t("chatbot.prompt.rag.final_thought_answer.opener")
      @inner_thoughts.each do |thought|
        if thought.key?('function_call')
          thoughts += I18n.t("chatbot.prompt.rag.final_thought_answer.thought_declaration", function_name: thought['function_call']['name'], arguments: thought['function_call']['arguments'])
        else
          thoughts += "#{thought['content']}\n\n"
        end
      end

      final_thought = {
        'role' => 'assistant',
        'content' => I18n.t("chatbot.prompt.rag.final_thought_answer.final_thought", thoughts: thoughts)
      }

      final_thought
    end
  end
end

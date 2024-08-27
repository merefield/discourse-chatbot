# frozen_string_literal: true
require "openai"

BUILT_IN_FUNCTIONS = ["DiscourseChatbot::StockDataFunction",
"DiscourseChatbot::GetCoordsOfLocationDescriptionFunction",
"DiscourseChatbot::GetDistanceBetweenLocationsFunction",
"DiscourseChatbot::ForumTopicSearchFromTopicLocationFunction",
"DiscourseChatbot::ForumTopicSearchFromUserLocationFunction",
"DiscourseChatbot::ForumTopicSearchFromLocationFunction",
"DiscourseChatbot::ForumGetUserAddressFunction",
"DiscourseChatbot::ForumUserSearchFromTopicLocationFunction",
"DiscourseChatbot::ForumUserSearchFromUserLocationFunction",
"DiscourseChatbot::ForumUserSearchFromLocationFunction",
"DiscourseChatbot::ForumUserDistanceFromLocationFunction",
"DiscourseChatbot::ForumSearchFunction",
"DiscourseChatbot::PaintFunction",
"DiscourseChatbot::VisionFunction",
"DiscourseChatbot::WikipediaFunction",
"DiscourseChatbot::WebSearchFunction",
"DiscourseChatbot::WebCrawlerFunction",
"DiscourseChatbot::NewsFunction",
"DiscourseChatbot::EscalateToStaffFunction",
"DiscourseChatbot::CalculatorFunction"]

module ::DiscourseChatbot

  class OpenAiBotRag < OpenAIBotBase

    NOT_FORCED = "not_forced"
    FORCE_A_FUNCTION = "force_a_function"
    FORCE_LOCAL_SEARCH_FUNCTION = "force_local_forum_search"

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
      @posts_ids_found = []
      @topic_ids_found = []
      @non_post_urls_found = []

      @chat_history += prompt

      res = generate_response(opts)

      {
        reply: res["choices"][0]["message"]["content"],
        inner_thoughts: @inner_thoughts
      }
    end

    def merge_functions(opts)
      calculator_function = ::DiscourseChatbot::CalculatorFunction.new
      wikipedia_function = ::DiscourseChatbot::WikipediaFunction.new
      news_function = ::DiscourseChatbot::NewsFunction.new
      web_crawler_function = ::DiscourseChatbot::WebCrawlerFunction.new
      web_search_function = ::DiscourseChatbot::WebSearchFunction.new
      stock_data_function = ::DiscourseChatbot::StockDataFunction.new
      escalate_to_staff_function = ::DiscourseChatbot::EscalateToStaffFunction.new
      paint_function = ::DiscourseChatbot::PaintFunction.new
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

      if SiteSetting.chatbot_support_vision == "via_function"
        vision_function = ::DiscourseChatbot::VisionFunction.new
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
      functions << vision_function if vision_function
      functions << paint_function if SiteSetting.chatbot_support_picture_creation

      functions << user_search_from_location_function if user_search_from_location_function
      functions << user_search_from_user_location_function if user_search_from_user_location_function
      functions << get_coords_of_location_function if get_coords_of_location_function
      functions << user_distance_from_location_function if user_distance_from_location_function
      functions << get_distance_between_locations if get_distance_between_locations
      functions << get_user_address if get_user_address
      functions << escalate_to_staff_function if SiteSetting.chatbot_escalate_to_staff_function && opts[:private] && opts[:type] == ::DiscourseChatbot::MESSAGE
      functions << news_function if !SiteSetting.chatbot_news_api_token.blank?
      functions << web_crawler_function if !(SiteSetting.chatbot_firecrawl_api_token.blank? && SiteSetting.chatbot_jina_api_token.blank?)
      functions << web_search_function if !(SiteSetting.chatbot_serp_api_key.blank? && SiteSetting.chatbot_jina_api_token.blank?)
      functions << stock_data_function if !SiteSetting.chatbot_marketstack_key.blank?

      if ::DiscourseChatbot::Function.descendants.count > BUILT_IN_FUNCTIONS.count
        ::DiscourseChatbot::Function.descendants.each do |func|
          functions << func.new if !BUILT_IN_FUNCTIONS.include?(func.to_s)
        end
      end

      @functions = parse_functions(functions)
      @tools = @functions.map { |func| { "type": "function", "function": func } }
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

    def create_chat_completion(messages, use_functions = true, iteration)
      begin
        ::DiscourseChatbot.progress_debug_message <<~EOS
          I called the LLM to help me
          ------------------------------
          value of messages is: #{JSON.pretty_generate(messages)}
          +++++++++++++++++++++++++++++++
        EOS
        parameters = {
          model: @model_name,
          messages: messages,
          max_tokens: SiteSetting.chatbot_max_response_tokens,
          temperature: SiteSetting.chatbot_request_temperature / 100.0,
          top_p: SiteSetting.chatbot_request_top_p / 100.0,
          frequency_penalty: SiteSetting.chatbot_request_frequency_penalty / 100.0,
          presence_penalty: SiteSetting.chatbot_request_presence_penalty / 100.0
        }

        if use_functions && @tools
          parameters.merge!(tools: @tools)
          if iteration == 1
            if SiteSetting.chatbot_tool_choice_first_iteration == FORCE_A_FUNCTION
              parameters.merge!(tool_choice: "required")
            elsif SiteSetting.chatbot_tool_choice_first_iteration == FORCE_LOCAL_SEARCH_FUNCTION
              parameters.merge!(tool_choice: {"type": "function", "function": {"name": "local_forum_search"}})
            end
          end
        end

        res = @client.chat(
          parameters: parameters
        )

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
          Rails.logger.error("Chatbot: There was a problem with Chat Completion: status: #{status}, message: #{message}")
        end
        raise e
      end
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
        res = create_chat_completion(@chat_history + @inner_thoughts, true, iteration)

        if res.dig("error")
          error_text = "ERROR when trying to perform chat completion: #{res.dig("error", "message")}"

          Rails.logger.error("Chatbot: #{error_text}")
        end

        finish_reason = res["choices"][0]["finish_reason"]
        tools_calls = res["choices"][0]["message"]["tool_calls"]

        # the tools calls check is a workaround and is required because sending a query with tools: required leads to an apparently incorrect finish reason.

        if (['stop','length'].include?(finish_reason) && tools_calls.nil? || @inner_thoughts.length > 7)
          if iteration > 1 && SiteSetting.chatbot_url_integrity_check
            if legal_post_urls?(res["choices"][0]["message"]["content"], @posts_ids_found, @topic_ids_found) && legal_non_post_urls?(res["choices"][0]["message"]["content"], @non_post_urls_found)
              return res
            else
              @inner_thoughts << { role: 'user', content: I18n.t("chatbot.prompt.system.rag.illegal_urls") }
            end
          else
            return res
          end
        elsif finish_reason == 'tool_calls' || !tools_calls.nil?
          handle_function_call(res, opts)
        else
          raise "Unexpected finish reason: #{finish_reason}"
        end

        # If the response is an image, we don't want to continue the loop of thought
        return {
          "choices" => [
              {
                "message" => {
                  "content" => "#{@inner_thoughts.last[:content]}"
                }
              }
            ]
        } if image_url?(@inner_thoughts.last[:content])

        iteration += 1
      end
    end

    def handle_function_call(res, opts)
      res_msgs = []
      functions_called = res["choices"][0]["message"]

      tools_called =  functions_called["tool_calls"]

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

      tools_thought = {
        "role": "assistant",
        "content": "",
        "tool_calls": ruby_object_array
      }

      @inner_thoughts << tools_thought

      tools_called.each do |function_called|
        func_name = function_called["function"]["name"]
        args_str = function_called["function"]["arguments"]
        tool_call_id = function_called["id"]
        if func_name == "local_forum_search"
          result_hash = call_function(func_name, args_str, opts)
          result, post_ids_found, topic_ids_found, non_post_urls_found = result_hash.values_at(:result, :post_ids_found, :topic_ids_found, :non_post_urls_found)
          @posts_ids_found = (@posts_ids_found.to_set | (post_ids_found&.to_set || Set.new)).to_a
          @topic_ids_found = (@topic_ids_found.to_set | (topic_ids_found&.to_set || Set.new)).to_a
          @non_post_urls_found = (@non_post_urls_found.to_set | (non_post_urls_found&.to_set || Set.new)).to_a
        else
          result = call_function(func_name, args_str, opts)
        end
        @inner_thoughts << { role: 'tool', tool_call_id: tool_call_id, content: result.to_s }
      end
    end

    def call_function(func_name, args_str, opts)
      ::DiscourseChatbot.progress_debug_message <<~EOS
        +++++++++++++++++++++++++++++++++++++++
        I used '#{func_name}' to help me
        args_str was '#{JSON.pretty_generate(JSON.parse(args_str))}'
        opts was '#{JSON.pretty_generate(opts)}'
        +++++++++++++++++++++++++++++++++++++++
      EOS
      begin
        args = JSON.parse(args_str)
        func = @func_mapping[func_name]
        if ["escalate_to_staff"].include?(func_name)
          res = func.process(args, opts)
        elsif ["vision"].include?(func_name)
          res = func.process(args, opts, @client)
        else
          res = func.process(args)
        end
        res
       rescue
         I18n.t("chatbot.prompt.rag.call_function.error")
      end
    end

    def legal_post_urls?(res, post_ids_found, topic_ids_found)
      return true if res.blank?

      post_url_regex = ::DiscourseChatbot::POST_URL_REGEX
      topic_url_regex = ::DiscourseChatbot::TOPIC_URL_REGEX

      topic_ids_in_text = res.scan(topic_url_regex).flatten
      post_combos_in_text = res.scan(post_url_regex)

      topic_ids_in_text.each do |topic_id_in_text|
        if !topic_ids_found.include?(topic_id_in_text.to_i)
          return false
        end
      end

      post_combos_in_text.each do |post_combo|
        topic_id_in_text = post_combo[0]
        post_number_in_text = post_combo[1]

        post = ::Post.find_by(topic_id: topic_id_in_text.to_i, post_number: post_number_in_text.to_i)

        if post.nil? || !post_ids_found.include?(post.id)
          return false
        end
      end

      true
    end

    def legal_non_post_urls?(res, non_post_urls_found)
      return true if res.blank?
      non_post_url_regex = ::DiscourseChatbot::NON_POST_URL_REGEX

      urls_in_text = res.scan(non_post_url_regex)

      urls_in_text = urls_in_text.reject { |url| url.include?('/t/') }

      urls_in_text.each do |url|
        if !non_post_urls_found.include?(url)
          return false
        end
      end
      true
    end

    private

    def image_url?(string)
      # Regular expression to find URLs
      url_regex = /\bhttps?:\/\/[^\s]+/

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

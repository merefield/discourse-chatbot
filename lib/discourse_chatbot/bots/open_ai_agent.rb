# frozen_string_literal: true
require "openai"

module ::DiscourseChatbot

  class OpenAIAgent < OpenAIBotBase

    def initialize
      super

      calculator_function = ::DiscourseChatbot::CalculatorFunction.new
      wikipedia_function = ::DiscourseChatbot::WikipediaFunction.new
      news_function = ::DiscourseChatbot::NewsFunction.new
      google_search_function = ::DiscourseChatbot::GoogleSearchFunction.new
      forum_search_function = ::DiscourseChatbot::ForumSearchFunction.new
      stock_data_function = ::DiscourseChatbot::StockDataFunction.new

      functions = [calculator_function, wikipedia_function, forum_search_function]

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

    def generate_response
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
        res = create_chat_completion(@chat_history + @internal_thoughts)
        finish_reason = res["choices"][0]["finish_reason"]

        if finish_reason == 'stop' || @internal_thoughts.length > 5
          final_thought = final_thought_answer
          final_res = create_chat_completion(
            @chat_history + [final_thought],
            false
          )
          # pp final_res
          return final_res
        elsif finish_reason == 'function_call'
          handle_function_call(res)
        else
          raise "Unexpected finish reason: #{finish_reason}"
        end
        iteration += 1
      end
    end

    def handle_function_call(res)
      first_message = res["choices"][0]["message"]
      @internal_thoughts << first_message.to_hash
      func_name = first_message["function_call"]["name"]
      args_str = first_message["function_call"]["arguments"]
      result = call_function(func_name, args_str)
      res_msg = { 'role' => 'assistant', 'content' => I18n.t("chatbot.prompt.agent.handle_function_call.answer", result: result) }
      @internal_thoughts << res_msg
    end

    def call_function(func_name, args_str)
      ::DiscourseChatbot.progress_debug_message <<~EOS
        +++++++++++++++++++++++++++++++++++++++
        I used '#{func_name}' to help me
        +++++++++++++++++++++++++++++++++++++++
      EOS
      begin
        args = JSON.parse(args_str)
        func = @func_mapping[func_name]
        res = func.process(args)
        res
       rescue
         I18n.t("chatbot.prompt.agent.call_function.error")
      end
    end

    def final_thought_answer
      thoughts = I18n.t("chatbot.prompt.agent.final_thought_answer.opener")
      @internal_thoughts.each do |thought|
        if thought.key?('function_call')
          thoughts += I18n.t("chatbot.prompt.agent.final_thought_answer.function_declaration", function_name: thought['function_call']['name'], arguments: thought['function_call']['arguments'])
        else
          thoughts += "#{thought['content']}\n\n"
        end
      end

      final_thought = {
        'role' => 'assistant',
        'content' => I18n.t("chatbot.prompt.agent.final_thought_answer.final_thought", thoughts: thoughts)
      }

      final_thought
    end

    def get_response(prompt)
      system_message = { "role": "system", "content": I18n.t("chatbot.prompt.system.agent", current_date_time: DateTime.current) }
      prompt.unshift(system_message)

      @internal_thoughts = []

      @chat_history += prompt

      res = generate_response

      @chat_history << res["choices"][0]["message"].to_hash
      res["choices"][0]["message"]["content"]
    end

    def ask(opts)
      super(opts)
    end
  end
end

# frozen_string_literal: true
require "openai"

#import json
#from typing import Optional
#from funkagent import parser
require 'json'

# require_relative '../function.rb'
# require_relative '../functions/parser.rb'
# require_relative '../functions/calculator_function'
# require_relative '../functions/get_news_function'
# require_relative '../functions/lookup_wikipedia_function'

module ::DiscourseChatbot

  class OpenAIAgent < Bot
  #   SYS_MSG = <<~MSG.freeze
  #   Assistant is a large language model trained by OpenAI.

  #   Assistant is designed to be able to assist with a wide range of tasks, from answering simple questions to providing in-depth explanations and discussion on a wide range of topics. As a language model, Assistant is able to generate human-like text based on the input it receives, allowing it to engage in natural-sounding conversations and provide responses that are coherent and relevant to the topic at hand.

  #   Assistant is constantly learning and improving, and its capabilities are constantly evolving. It is able to process and understand large amounts of text, and can use this knowledge to provide accurate and informative responses to a wide range of questions. Additionally, Assistant is able to generate its own text based on the input it receives, allowing it to engage in discussions and provide explanations and descriptions on a wide range of topics.

  #   Overall, Assistant is a powerful system that can help with a wide range of tasks and provide valuable insights and information on a wide range of topics. Whether you need help with a specific question or just want to have a conversation about a particular topic, Assistant is here to assist.

  #   Only use the functions you have been provided with.  The news function provides current news and should be respected as you have no other source of current news.
  # MSG

  SYS_MSG = <<~MSG.freeze
  You are an energetic Fox News anchor that likes to respond with humour.  You have great tools in the form of functions that give you the power to get newer information.
  
  Only use the functions you have been provided with.  The news function provides current news and should be respected as you have no other source of current news.
MSG
#'gpt-3.5-turbo-0613'
#model_name = 'gpt-4-0613'
#(openai_api_key, functions = nil, verbose_output = true, model_name = 'gpt-3.5-turbo-0613')
    def initialize
      
      @client = ::OpenAI::Client.new(access_token: SiteSetting.chatbot_open_ai_token)
      @model_name = SiteSetting.chatbot_open_ai_model_custom ? SiteSetting.chatbot_open_ai_model_custom_name : SiteSetting.chatbot_open_ai_model


      calculator_function = ::DiscourseChatbot::CalculatorFunction.new
      wikipedia_function = ::DiscourseChatbot::WikipediaFunction.new
      news_function = ::DiscourseChatbot::NewsFunction.new

      functions = [calculator_function, wikipedia_function]

      functions << news_function if !SiteSetting.chatbot_news_api_token.blank?

      @functions = parse_functions(functions)
      @func_mapping = create_func_mapping(functions)
      @chat_history = [{'role' => 'system', 'content' => SYS_MSG}]
      # @verbose_output = verbose_output
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
      res_msg = {'role' => 'assistant', 'content' => "The answer is #{result}."}
      @internal_thoughts << res_msg
    end

    def call_function(func_name, args_str)
      ::DiscourseChatbot.progress_debug_message <<~EOS
        +++++++++++++++++++++++++++++++++++++++
        I used '#{func_name}' to help me
        +++++++++++++++++++++++++++++++++++++++
      EOS
      # pp args_str
      # byebug
      begin
       args = JSON.parse(args_str)
       func = @func_mapping[func_name]
       res = func.process(*args.values)
       res
      rescue
       pp args_str
       raise "Dodgy args"
      end
    end

    def final_thought_answer
      thoughts = "To answer the question I will use these step by step instructions.\n\n"
      @internal_thoughts.each do |thought|
        if thought.key?('function_call')
          thoughts += "I will use the #{thought['function_call']['name']} function to calculate the answer with arguments #{thought['function_call']['arguments']}.\n\n"
        else
          thoughts += "#{thought['content']}\n\n"
        end
      end
      final_thought = {
        'role' => 'assistant',
        'content' => "#{thoughts} Based on the above, I will now answer the question, this message will only be seen by me so answer with the assumption with that the user has not seen this message."
      }
      final_thought
    end

    def get_response(query)
      @internal_thoughts = []
      @chat_history << {'role' => 'user', 'content' => query}
      res = generate_response
      @chat_history << res["choices"][0]["message"].to_hash
      res["choices"][0]["message"]["content"]
    end

    
    def ask(opts)
      super(opts)
    end
  end
end

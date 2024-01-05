# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::OpenAiBotRag do
  let(:opts) { {} }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }
  let(:llm_function_response) { get_chatbot_fixture("llm_function_response") }
  let(:llm_interim_response) { get_chatbot_fixture("llm_interim_response") }
  let(:llm_final_response) { get_chatbot_fixture("llm_final_response") }

  it "calls function on returning a function request from LLN" do
    DateTime.expects(:current).returns("2023-08-18T10:11:44+00:00")

    system_entry = { role: "system", content: "You are a helpful assistant.  You have great tools in the form of functions that give you the power to get newer information. Only use the functions you have been provided with.  The current date and time is 2023-08-18T10:11:44+00:00.  When referring to users by name, include an @ symbol directly in front of their username.  Only respond to the last question, using the prior information as context, if appropriate." }

    query = [{ "role": "user", "content" => "what is 3 * 23.452432?" }]
    second_query = [system_entry, { :role => "user", "content" => "what is 3 * 23.452432?" }, { "role" => "assistant", "content" => nil, "function_call" => { "name" => "calculate", "arguments" => "{\n  \"input\": \"3 * 23.452432\"\n}" } }, { "role" => "function", "name" => "calculate", "content" => "The answer is 70.357296." }]
    final_query = [system_entry, { :role => "user", "content" => "what is 3 * 23.452432?" }, { "role" => "assistant", "content" => "To answer the question I will use these step by step instructions.\n\nI will use the calculate function to calculate the answer with arguments {\n  \"input\": \"3 * 23.452432\"\n}.\n\nThe answer is 70.357296.\n\n Based on the above, I will now answer the question, this message will only be seen by me so answer with the assumption with that the user has not seen this message." }]

    ::DiscourseChatbot::OpenAiBotRag.any_instance.expects(:create_chat_completion).with(query).returns(llm_function_response)
    ::DiscourseChatbot::OpenAiBotRag.any_instance.expects(:create_chat_completion).with(second_query).returns(llm_interim_response)
    ::DiscourseChatbot::OpenAiBotRag.any_instance.expects(:create_chat_completion).with(final_query, false).returns(llm_final_response)

    expect(rag.get_response(query, opts)[:reply]).to eq(llm_final_response["choices"][0]["message"]["content"])
  end
end

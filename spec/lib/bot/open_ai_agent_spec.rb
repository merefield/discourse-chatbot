# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::OpenAiBotRag do
  let(:opts) { {} }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }
  let(:llm_function_response) { get_chatbot_output_fixture("llm_function_response") }
  let(:llm_final_response) { get_chatbot_output_fixture("llm_final_response") }
  let(:post_ids_found) { [] }
  let(:topic_ids_found) { [111, 222, 3333] }

  fab!(:topic_1) { Fabricate(:topic, id: 112) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, post_number: 2) }
  let(:post_ids_found_2) { [post_1.id] }
  let(:res) {"the value is 90 and I found that informaiton in [this topic](https://discourse.example.com/t/slug/112)"}
  let(:res_2) {"the value is 99 and I found that informaiton in [this post](https://discourse.example.com/t/slug/112/2)"}

  it "calls function on returning a function request from LLN" do
    DateTime.expects(:current).returns("2023-08-18T10:11:44+00:00")

    query = [{role: "user", content: "merefield said what is 3 * 23.452432?" }]

    system_entry = { role: "system", content: "You are a helpful assistant.  You have great tools in the form of functions that give you the power to get newer information. Only use the functions you have been provided with.  The current date and time is 2023-08-18T10:11:44+00:00.  When referring to users by name, include an @ symbol directly in front of their username.  Only respond to the last question, using the prior information as context, if appropriate." }

    first_query =  get_chatbot_input_fixture("llm_first_query").unshift(system_entry)
    second_query = get_chatbot_input_fixture("llm_second_query").unshift(system_entry)

    described_class.any_instance.expects(:create_chat_completion).with(first_query, true, 1).returns(llm_function_response)
    described_class.any_instance.expects(:create_chat_completion).with(second_query, true, 2).returns(llm_final_response)

    expect(rag.get_response(query, opts)[:reply]).to eq(llm_final_response["choices"][0]["message"]["content"])
  end

  it "returns correct status for a response that includes and illegal topic id" do
    result = rag.legal_urls?(res, post_ids_found, topic_ids_found)

    expect(result).to eq(false)
  end

  it "returns correct status for a response that includes a legal post id" do
    expect(post_1).to be_present
    result = rag.legal_urls?(res_2, post_ids_found_2, topic_ids_found)
    expect(result).to eq(true)
  end
end
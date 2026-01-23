# frozen_string_literal: true
require_relative '../../plugin_helper'

RSpec.configure do |config|
  config.prepend_before(:suite) do
    User.find_by(username: "Chatbot") || Fabricate(:user, username: "Chatbot")
  end
end

describe ::DiscourseChatbot::OpenAiBotRag do
  let(:opts) { {} }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }
  let(:llm_function_response) { get_chatbot_output_fixture("llm_function_response") }
  let(:llm_final_response) { get_chatbot_output_fixture("llm_final_response") }
  let(:post_ids_found) { [] }
  let(:topic_ids_found) { [111, 222, 3333] }

  fab!(:topic_user) { Fabricate(:user, email: "topic_#{SecureRandom.hex}@example.com") }
  fab!(:post_user) { Fabricate(:user, email: "post_#{SecureRandom.hex}@example.com") }
  fab!(:topic_1) { Fabricate(:topic, id: 112, user: topic_user) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, user: post_user, post_number: 2) }

  before do
    SiteSetting.discourse_local_dates_enabled = false
  end
  let(:post_ids_found_2) { [post_1.id] }
  let(:res) {"the value is 90 and I found that informaiton in [this topic](https://discourse.example.com/t/slug/112)"}
  let(:res_2) {"the value is 99 and I found that informaiton in [this post](https://discourse.example.com/t/slug/112/2)"}

  it "calls function on returning a function request from LLN" do
    DateTime.expects(:current).returns("2023-08-18T10:11:44+00:00")

    query = [{role: "user", content: "merefield said what is 3 * 23.452432?" }]

    system_entry = { role: "developer", content: "You are a helpful assistant.  You have great tools in the form of functions that give you the power to get newer information. Only use the functions you have been provided with.  The current date and time is 2023-08-18T10:11:44+00:00.  When referring to users by name, include an @ symbol directly in front of their username.  Only respond to the last question, using the prior information as context, if appropriate." }

    first_query =  get_chatbot_input_fixture("llm_first_query").unshift(system_entry)
    second_query = get_chatbot_input_fixture("llm_second_query").unshift(system_entry)

    described_class.any_instance.expects(:create_chat_completion).with(first_query, true, 1).returns(llm_function_response)
    described_class.any_instance.expects(:create_chat_completion).with(second_query, true, 2).returns(llm_final_response)

    expect(rag.get_response(query, opts)[:reply]).to eq(llm_final_response["choices"][0]["message"]["content"])
  end

  it "returns correct status for a response that includes and illegal topic id" do
    result = rag.legal_post_urls?(res, post_ids_found, topic_ids_found)

    expect(result).to eq(false)
  end

  it "returns correct status for a response that includes a legal post id" do
    expect(post_1).to be_present
    result = rag.legal_post_urls?(res_2, post_ids_found_2, topic_ids_found)
    expect(result).to eq(true)
  end

  it "correctly identifies a legal post id in a url in a response" do
    expect(described_class.new({}).legal_post_urls?("hello /t/slug/112/2", [post_1.id], [topic_1.id])).to eq(true)
  end

  it "correctly skips a full url check if a response is blank" do
    expect(described_class.new({}).legal_post_urls?("", [post_1.id], [topic_1.id])).to eq(true)
  end

  it "correctly identifies an illegal topic id in a url in a response" do
    expect(described_class.new({}).legal_post_urls?("hello /t/slug/113/2", [post_1.id], [topic_1.id])).to eq(false)
  end

  it "correctly identifies an illegal non-post url in a response" do
    expect(described_class.new({}).legal_non_post_urls?("hello https://someplace.com/t/slug/113/2 try looking at https://notanexample.com it's great", ["https://example.com", "https://otherexample.com"])).to eq(false)
  end

  it "correctly identifies a legal non-post url in a response" do
    expect(described_class.new({}).legal_non_post_urls?("hello https://someplace.com/t/slug/113/2 try looking at https://example.com it's great", ["https://example.com", "https://otherexample.com"])).to eq(true)
  end
end

describe ::DiscourseChatbot::OpenAiBotRag, "#get_system_message_suffix" do
  let(:user) { Fabricate(:user, email: "user_#{SecureRandom.hex}@example.com") }
  let(:opts) { { user_id: user.id } }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }

  before do
    SiteSetting.discourse_local_dates_enabled = false
  end

  it "returns custom field prompts when enabled" do
    SiteSetting.chatbot_include_custom_field_prompts = true
    SiteSetting.chatbot_user_fields_collection = false

    ::UserCustomField.create!(
      user_id: user.id,
      name: "chatbot_additional_prompt",
      value: "Bring a laptop."
    )

    expect(rag.get_system_message_suffix(opts)).to eq("Bring a laptop.")
  end

  it "returns empty when custom field prompts are disabled" do
    SiteSetting.chatbot_include_custom_field_prompts = false
    SiteSetting.chatbot_user_fields_collection = false

    ::UserCustomField.create!(
      user_id: user.id,
      name: "chatbot_additional_prompt",
      value: "Bring a laptop."
    )

    expect(rag.get_system_message_suffix(opts)).to eq("")
  end
end

describe ::DiscourseChatbot::OpenAiBotRag,
         "#get_system_message_suffix via api",
         type: :request do
  let(:user) { Fabricate(:user, email: "api_user_#{SecureRandom.hex}@example.com") }
  let(:admin) { Fabricate(:admin, email: "api_admin_#{SecureRandom.hex}@example.com") }
  let(:api_key) { Fabricate(:api_key, user: admin) }
  let(:opts) { { user_id: user.id } }
  let(:rag) { ::DiscourseChatbot::OpenAiBotRag.new(opts) }

  before do
    SiteSetting.discourse_local_dates_enabled = false
    SiteSetting.chatbot_include_custom_field_prompts = true
    SiteSetting.chatbot_user_fields_collection = false

  end

  after do
    DiscoursePluginRegistry.reset_register!(:self_editable_user_custom_fields)
    DiscoursePluginRegistry.reset_register!(:staff_editable_user_custom_fields)
  end

  it "reads custom field prompts updated via api key" do
    put "/u/#{user.username}.json",
        params: {
          custom_fields: {
            chatbot_additional_prompt: "Bring a laptop."
          }
        },
        headers: { HTTP_API_KEY: api_key.key }

    expect(response.status).to eq(200)
    expect(rag.get_system_message_suffix(opts)).to eq("Bring a laptop.")
  end
end

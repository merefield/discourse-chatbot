# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::OpenAIAgent do
  let(:agent) { ::DiscourseChatbot::OpenAIAgent.new }

  let(:llm_function_response) {
    {
      "id"=>"chatcmpl-7oclPFxW1ggGvnk8ZY8diuWp5UULp",
      "object"=>"chat.completion",
      "created"=>1692299763,
      "model"=>"gpt-4-0613",
      "choices"=>[
        { "index"=> 0,
          "message"=> {
            "role"=>"assistant",
            "content"=> nil,
            "function_call" => {
              "name" => "calculate",
              "arguments" => "{\n  \"input\": \"3 * 23.452432\"\n}"
            }
          },
          "finish_reason" => "function_call"
        }
      ],
      "usage" => {
        "prompt_tokens" => 895,
        "completion_tokens" => 20,
        "total_tokens" => 915
      }
    }
  }

let(:llm_interim_response) {
  {
    "id" => "chatcmpl-7oclSemwPSYrzSnIyWxJYAEeV1pt2",
    "object" => "chat.completion",
    "created"=>1692299766,
    "model" => "gpt-4-0613",
    "choices" => [
      {
        "index" => 0,
        "message" => {
          "role" => "assistant",
          "content" => "Isn't that just like a calculator - exact, precise, and no fun at all! Until we gave it colors and cute buttons, of course. Anyways, your result Merefield, is 70.357296. I hope this piece of information weighty with the solemn gravity of mathematical certainty adds a little zing to your day! What's the next riddle you've got for me?"
          },
        "finish_reason" => "stop"
      }
    ],
    "usage" => {
      "prompt_tokens" => 931,
      "completion_tokens" => 83,
      "total_tokens" => 1014
    }
  }
}

let(:llm_final_response) {
  {
    "id" => "chatcmpl-7oclZEJflBuxcLneEBE1dVIwe7KEn",
    "object" => "chat.completion",
    "created" => 1692299773,
    "model" => "gpt-4-0613",
    "choices" => [
      {
        "index" => 0,
        "message" => {
          "role" => "assistant",
          "content" => "Well, Merefield, If you measure a fish once it's three times as impressive, isn't it? Much like 3 multiplied by 23.452432 is three times as precise and lands at a whopping 70.357296. \n\nThat's almost as many puns as I have ready for this broadcast! Keep those numbers comin' and I'll keep the humor flowin'!"
        },
        "finish_reason" => "stop"
      }
    ],
    "usage" => {
      "prompt_tokens" => 460,
      "completion_tokens" => 82,
      "total_tokens" => 542
    }
  }
}

  it "calls function on returning a function request from LLN" do
    query = [{ "role": "user", "content" => "what is 3 * 23.452432?"}]
    second_query = [{:role => "user", "content" => "what is 3 * 23.452432?"}, {"role" => "assistant", "content" => nil, "function_call" => {"name" => "calculate", "arguments" => "{\n  \"input\": \"3 * 23.452432\"\n}"}}, {"role" => "assistant", "content" => "The answer is 70.357296."}]
    final_query = [{:role => "user", "content" => "what is 3 * 23.452432?"}, {"role" => "assistant", "content" => "To answer the question I will use these step by step instructions.\n\nI will use the calculate function to calculate the answer with arguments {\n  \"input\": \"3 * 23.452432\"\n}.\n\nThe answer is 70.357296.\n\n Based on the above, I will now answer the question, this message will only be seen by me so answer with the assumption with that the user has not seen this message."}]

    ::DiscourseChatbot::OpenAIAgent.any_instance.expects(:create_chat_completion).with(query).returns(llm_function_response)
    ::DiscourseChatbot::OpenAIAgent.any_instance.expects(:create_chat_completion).with(second_query).returns(llm_interim_response)
    ::DiscourseChatbot::OpenAIAgent.any_instance.expects(:create_chat_completion).with(final_query, false).returns(llm_final_response)

    expect(agent.get_response(query)).to eq(llm_final_response["choices"][0]["message"]["content"])
  end
end

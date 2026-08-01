# frozen_string_literal: true

require_relative "../../plugin_helper"

describe ::DiscourseChatbot::PostPromptUtils do
  fab!(:bot_user, :user)
  fab!(:human_user, :user)
  fab!(:staff_user, :admin)
  fab!(:topic) { Fabricate(:topic, user: human_user) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: human_user) }

  it "excludes bot inner-thought posts without excluding staff whispers or consuming history capacity" do
    SiteSetting.chatbot_include_whispers_in_post_history = true
    SiteSetting.chatbot_max_look_behind = 3
    staff_whisper = Fabricate(:post, topic: topic, user: staff_user, post_type: Post.types[:whisper])
    inner_thoughts_raw =
      ::DiscourseChatbot::INNER_THOUGHTS_POST_PREFIX + "[]\n```\n[/details]"
    inner_thoughts_whisper =
      Fabricate(
        :post,
        topic: topic,
        user: bot_user,
        post_type: Post.types[:whisper],
        raw: inner_thoughts_raw,
      )
    inner_thoughts_regular =
      Fabricate(:post, topic: topic, user: bot_user, raw: inner_thoughts_raw)
    bot_response = Fabricate(:post, topic: topic, user: bot_user)
    current_post = Fabricate(:post, topic: topic, user: human_user)

    prompt =
      described_class.create_prompt(
        reply_to_message_or_post_id: current_post.id,
        original_post_number: current_post.post_number,
        bot_user_id: bot_user.id,
        category_id: topic.category_id,
      )
    serialized_prompt = JSON.generate(prompt)

    expect(serialized_prompt).to include(staff_whisper.raw, bot_response.raw, current_post.raw)
    expect(serialized_prompt).not_to include(
      inner_thoughts_whisper.raw,
      inner_thoughts_regular.raw,
    )
  end
end

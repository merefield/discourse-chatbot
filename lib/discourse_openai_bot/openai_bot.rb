# frozen_string_literal: true
require "openai"

module ::DiscourseOpenAIBot

  class OpenAIBot < StandardError; end

  class OpenAIBot

    def initialize
     
      # TODO add this in when support added via PR after "ruby-openai", '3.3.0'
      # OpenAI.configure do |config|
      #   config.request_timeout = 25
      # end
  
      @client = ::OpenAI::Client.new(access_token: SiteSetting.openai_bot_open_ai_token)
        # , params: {key: openai_bot_api_key, cb_settings_tweak1: wackiness, cb_settings_tweak2: talkativeness, cb_settings_tweak3: attentiveness})
    end


    def get_response(prompt)
      response = @client.completions(
        parameters: {
            model: SiteSetting.openai_bot_open_ai_model,
            prompt: "#{prompt}",
            max_tokens: SiteSetting.openai_bot_max_response_tokens
        })
  
      if response.parsed_response["error"]
        raise StandardError, response.parsed_response["error"]["message"]
      end
  
      final_text = response["choices"][0]["text"]
    end

    def collect_past_posts(post_id)
      
      current_post = Post.find(post_id)

      post_collection = []

      post_collection << current_post

      collect_amount = SiteSetting.openai_bot_max_look_behind

      while post_collection.length < collect_amount do
      
        if current_post.reply_to_post_number
          current_post = Post.find_by(topic_id: current_post.topic_id, post_number: current_post.reply_to_post_number)
        else
          if current_post.post_number > 1
            current_post = Post.where(topic_id: current_post.topic_id, deleted_at: nil).where('post_number < ?', current_post.post_number).last
          else
            break
          end
        end

        post_collection << current_post
      end

      post_collection
    end




    def ask(opts)
      openai_bot_response = ""
      input_data = ""

      msg = opts[:message_body]

     # post = ::Post.find_by(id: opts[:reply_to_post_id])

      post_collection = collect_past_posts(opts[:reply_to_post_id])

      content = post_collection.reverse.map { |p| <<~MD }
      #{p.user.username}
      #{p.raw}
      ---
      MD

     byebug
      
      # .downcase
      #conv_id = opts[:conversation_id] || nil
      # topic_id = opts[:topic_id]

      # user_id = opts[:user_id]

      #msg = CGI.unescapeHTML(msg.gsub(/[^a-zA-Z0-9 ]+/, "")).gsub(/[^A-Za-z0-9]/, " ").strip

      #params = {input: msg, conversation_id: conv_id}
      #Topic.find_by(id:topic_id).conversation_id = response.id

      response = get_response(content)
    end
  end
end

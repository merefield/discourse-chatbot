# frozen_string_literal: true
module ::DiscourseChatbot

  class PostPromptUtils < PromptUtils

    def self.create_prompt(opts)
      post_collection = collect_past_interactions(opts[:reply_to_message_or_post_id])
      bot_user_id = opts[:bot_user_id]

      if SiteSetting.chatbot_open_ai_model == "gpt-3.5-turbo"
        if SiteSetting.chatbot_enforce_system_role == true
          messages = [{ "role": "user", "content":  I18n.t("chatbot.prompt.title", topic_title: post_collection.first.topic.title) }]
          messages << { "role": "user", "content": I18n.t("chatbot.prompt.first_post", username: post_collection.first.topic.first_post.user.username, raw: post_collection.first.topic.first_post.raw) }

          messages += post_collection.reverse.map { |p|
            { "role": (p.user_id == bot_user_id ? "assistant" : "user"), "content": (p.user_id == bot_user_id ? "#{p.raw}" : I18n.t("chatbot.prompt.post", username: p.user.username, raw: p.raw)) }
          }

          messages << { "role": "system", "content": I18n.t("chatbot.prompt.system") }

          messages
        else
          messages = [{ "role": "system", "content": I18n.t("chatbot.prompt.system") }]
          messages << { "role": "user", "content":  I18n.t("chatbot.prompt.title", topic_title: post_collection.first.topic.title) }
          messages << { "role": "user", "content": I18n.t("chatbot.prompt.first_post", username: post_collection.first.topic.first_post.user.username, raw: post_collection.first.topic.first_post.raw) }

          messages += post_collection.reverse.map { |p|
            { "role": (p.user_id == bot_user_id ? "assistant" : "user"), "content": (p.user_id == bot_user_id ? "#{p.raw}" : I18n.t("chatbot.prompt.post", username: p.user.username, raw: p.raw)) }
          }

          if SiteSetting.chatbot_prio_system_role == true
            messages << { "role": "system", "content": I18n.t("chatbot.prompt.systemprio") }
          end

          messages
        end
      else
        content = post_collection.reverse.map { |p| <<~MD }
        #{I18n.t("chatbot.prompt.post", username: p.user.username, raw: p.raw)}
        ---
        MD
        content
      end
    end

    def self.collect_past_interactions(message_or_post_id)
      current_post = ::Post.find(message_or_post_id)

      post_collection = []

      post_collection << current_post

      collect_amount = SiteSetting.chatbot_max_look_behind

      while post_collection.length < collect_amount do
        if current_post.reply_to_post_number
          linked_post = ::Post.find_by(topic_id: current_post.topic_id, post_number: current_post.reply_to_post_number)
          unless linked_post
            break if current_post.reply_to_post_number == 1
            current_post = ::Post.where(topic_id: current_post.topic_id, deleted_at: nil).where('post_number < ?', current_post.reply_to_post_number).last
            next
          end
          current_post = linked_post
        else
          if current_post.post_number > 1
            current_post = ::Post.where(topic_id: current_post.topic_id, deleted_at: nil).where('post_number < ?', current_post.post_number).last
          else
            break
          end
        end

        post_collection << current_post
      end

      post_collection
    end
  end
end

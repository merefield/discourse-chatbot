# frozen_string_literal: true
module ::DiscourseChatbot
  class PostPromptUtils < PromptUtils
    def self.create_prompt(opts)
      current_post = ::Post.find(opts[:reply_to_message_or_post_id])
      current_topic = current_post.topic
      first_post = current_topic.first_post
      post_collection = collect_past_interactions(current_post.id)
      original_post_number = opts[:original_post_number]
      bot_user_id = opts[:bot_user_id]
      category_id = opts[:category_id]
      first_post_role =
       first_post.user.id == bot_user_id ? "assistant" : "user"
      messages =
        (
          if SiteSetting.chatbot_api_supports_name_attribute ||
              first_post.user.id == bot_user_id
            [
              {
                role: first_post_role,
                name:first_post.user.username,
                content:
                  I18n.t("chatbot.prompt.title", topic_title:current_topic.title),
              },
            ]
          else
            [
              {
                role: first_post_role,
                content:
                  I18n.t("chatbot.prompt.title", topic_title:current_topic.title),
              },
            ]
          end
        )

      messages << create_message(first_post, opts)

      if original_post_number == 1 &&
           (
             Array(SiteSetting.chatbot_auto_respond_categories.split("|")).include? category_id.to_s
           ) &&
           !CategoryCustomField.find_by(
             category_id: category_id,
             name: "chatbot_auto_response_additional_prompt",
           ).blank?
        special_prompt_message =
          if (SiteSetting.chatbot_api_supports_name_attribute ||
              first_post.user.id == bot_user_id)
            {
              role: first_post_role,
              name: first_post.user.username,
              content:
                CategoryCustomField.find_by(
                  category_id: category_id,
                  name: "chatbot_auto_response_additional_prompt",
                ).value,
            }
          else
            {
              role: first_post_role,
              content:
                I18n.t("chatbot.prompt.post",
                  username: first_post.user.username,
                  raw: CategoryCustomField.find_by(
                    category_id: category_id,
                    name: "chatbot_auto_response_additional_prompt",
                  ).value)
            }
        end
        messages << special_prompt_message
      end

      if post_collection.length > 0
        messages += post_collection.reverse.map { |p| create_message(p, opts) }
      end

      messages
    end

    def self.create_message(p, opts)
      post_content = p.raw
      bot_user_id = opts[:bot_user_id]
      if SiteSetting.chatbot_strip_quotes
        post_content.gsub!(%r{\[quote.*?\](.*?)\[/quote\]}m, "")
      end
      role = p.user_id == bot_user_id ? "assistant" : "user"
      username = p.user.username

      text =
        (
          if SiteSetting.chatbot_api_supports_name_attribute || p.user_id == bot_user_id
            post_content
          else
            I18n.t("chatbot.prompt.post", username: username, raw: post_content)
          end
        )

      content = []

      content << { type: "text", text: text }
      upload_refs = UploadReference.where(target_id: p.id, target_type: "Post")
      upload_refs.each do |uf|
        upload = Upload.find(uf.upload_id)
        if %w[png webp jpg jpeg gif ico avif].include?(upload.extension) && SiteSetting.chatbot_support_vision == "directly" ||
            upload.extension == "pdf" && SiteSetting.chatbot_support_pdf == true
          role = "user"
          file_path = path = Discourse.store.path_for(upload)
          base64_encoded_data = Base64.strict_encode64(File.read(file_path))

          if upload.extension == "pdf"
            content << {
              "type": "file",
              "file": {
                  "filename": upload.original_filename,
                  "file_data": "data:application/pdf;base64," + base64_encoded_data
              }
            }
          else
            content << {
              "type": "image_url",
              "image_url": {
                "url": "data:image/#{upload.extension};base64," + base64_encoded_data
              }
            }
          end
        end
      end

      if SiteSetting.chatbot_api_supports_name_attribute
        { role: role, name: username, content: content }
      else
        { role: role, content: content }
      end
    end

    def self.collect_past_interactions(current_post_id)
      current_post = ::Post.find(current_post_id)
      current_topic_id = current_post.topic_id
      post_collection = []

      return post_collection if current_post.post_number == 1

      accepted_post_types =
        (
          if SiteSetting.chatbot_include_whispers_in_post_history
            ::DiscourseChatbot::POST_TYPES_INC_WHISPERS
          else
            ::DiscourseChatbot::POST_TYPES_REGULAR_ONLY
          end
        )

      post_collection << current_post

      collect_amount = SiteSetting.chatbot_max_look_behind

      while post_collection.length < collect_amount
        break if current_post.reply_to_post_number == 1
        if current_post.reply_to_post_number
          linked_post =
            ::Post.find_by(
              topic_id: current_topic_id,
              post_number: current_post.reply_to_post_number,
            )
          if linked_post
            current_post = linked_post
          else
            current_post =
              ::Post
                .where(
                  topic_id:current_topic_id,
                  post_type: accepted_post_types,
                  deleted_at: nil,
                )
                .where("post_number < ?", current_post.reply_to_post_number)
                .last
            break if current_post.post_number == 1
          end
        else
          if current_post.post_number > 1
            current_post =
              ::Post
                .where(
                  topic_id:current_topic_id,
                  post_type: accepted_post_types,
                  deleted_at: nil,
                )
                .where("post_number < ?", current_post.post_number)
                .last
            break if current_post.post_number == 1
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

# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumSearchFunction < Function

    def name
      'local_forum_search'
    end

    def description
      I18n.t("chatbot.prompt.function.forum_search.description")
    end

    def parameters
      [
        { name: "query", type: String, description: I18n.t("chatbot.prompt.function.forum_search.parameters.query") } ,
        { name: "number_of_posts", type: Integer, description: I18n.t("chatbot.prompt.function.forum_search.parameters.number_of_posts") }
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        super(args)

        top_topics = []
        top_topics_from_post_results = []
        top_topics_from_topic_title_results = []
        top_topic_title_results = []
        post_ids_found = []
        topic_ids_found = []
        query = args[parameters[0][:name]]
        number_of_posts = args[parameters[1][:name]].blank? ? 3 : args[parameters[1][:name]]
        number_of_posts = number_of_posts > SiteSetting.chatbot_forum_search_function_max_results ? SiteSetting.chatbot_forum_search_function_max_results : number_of_posts

        process_post_embedding = ::DiscourseChatbot::PostEmbeddingProcess.new
        results = process_post_embedding.semantic_search(query)
        top_results = results[0..(number_of_posts - 1)]

        if SiteSetting.chatbot_forum_search_function_include_topic_titles
          process_topic_title_embedding = ::DiscourseChatbot::TopicTitleEmbeddingProcess.new
          topic_title_results = process_topic_title_embedding.semantic_search(query)
          top_topic_title_results = topic_title_results[0..(number_of_posts - 1)]
        end

        if SiteSetting.chatbot_forum_search_function_results_content_type == "topic" || top_topic_title_results.length > 0
          top_topics_from_post_results = top_results.map { |result| ::Post.find(result[:post_id].to_i).topic_id }.uniq
          top_topics_from_topic_title_results = top_topic_title_results.map { |result| result[:topic_id].to_i }.uniq
          top_topics = (top_topics_from_post_results + top_topics_from_topic_title_results).uniq

          response = I18n.t("chatbot.prompt.function.forum_search.answer.topic.summary", number_of_topics: top_topics.length)

          accepted_post_types = SiteSetting.chatbot_include_whispers_in_post_history ? ::DiscourseChatbot::POST_TYPES_INC_WHISPERS : ::DiscourseChatbot::POST_TYPES_REGULAR_ONLY

          top_topics.each_with_index do |topic_id, index|
            top_post_result = {}
            top_post_result = top_results.find do |result|
              post_topic_id = ::Post.find(result[:post_id].to_i).topic_id
              post_topic_id == topic_id
            end

            top_topic_title_result = {}
            top_topic_title_result = top_topic_title_results.find do |result|
              topic_id == result[:topic_id]
            end

            original_post_number = nil

            if !top_post_result.blank?
              score = top_post_result[:score]
              original_post_number = ::Post.find(top_post_result[:post_id]).post_number
            else
              score = top_topic_title_result[:score]
            end

            current_topic = ::Topic.find(topic_id)
            url = "https://#{Discourse.current_hostname}/t/slug/#{current_topic.id}"
            title = current_topic.title
            response += I18n.t("chatbot.prompt.function.forum_search.answer.topic.each.topic", url: url, title: title, score: score, rank: index + 1)
            topic_ids_found << topic_id
            post_number = 1

            max_post_number = case SiteSetting.chatbot_forum_search_function_results_topic_max_posts_count_strategy
              when "all"
                Topic.find(topic_id).highest_post_number
              when "just_enough"
                original_post_number || SiteSetting.chatbot_forum_search_function_results_topic_max_posts_count
              when "stretch_if_required"
                (original_post_number || 0) > SiteSetting.chatbot_forum_search_function_results_topic_max_posts_count ? original_post_number : SiteSetting.chatbot_forum_search_function_results_topic_max_posts_count
              else
                SiteSetting.chatbot_forum_search_function_results_topic_max_posts_count
              end

            while post_number <= max_post_number do
              post = ::Post.find_by(topic_id: topic_id, post_number: post_number )
              break if post.nil?
              next if post.deleted_at || !accepted_post_types.include?(post.post_type)
              response += I18n.t("chatbot.prompt.function.forum_search.answer.topic.each.post", post_number: post_number, username: post.user.username, date: post.created_at, raw: post.raw)

              topic_ids_in_raw_urls_found, post_ids_in_raw_urls_found = find_post_and_topic_ids_from_raw_urls(post.raw)

              topic_ids_found = topic_ids_found | topic_ids_in_raw_urls_found
              post_ids_found = post_ids_found | post_ids_in_raw_urls_found

              post_ids_found << post.id
              post_number += 1
            end
          end
        else
          response = I18n.t("chatbot.prompt.function.forum_search.answer.post.summary", number_of_posts: number_of_posts)
          top_results.each_with_index do |result, index|
            current_post = ::Post.find(result[:post_id].to_i)
            score = result[:score]
            url = "https://#{Discourse.current_hostname}/t/slug/#{current_post.topic_id}/#{current_post.post_number}"
            raw = current_post.raw
            username = User.find(current_post.user_id).username
            date = current_post.created_at.to_date
            response += I18n.t("chatbot.prompt.function.forum_search.answer.post.each", url: url, username: username, date: date, raw: raw, score: score, rank: index + 1)

            topic_ids_in_raw_urls_found, post_ids_in_raw_urls_found = find_post_and_topic_ids_from_raw_urls(raw)

            topic_ids_found = topic_ids_found | topic_ids_in_raw_urls_found
            post_ids_found = post_ids_found | post_ids_in_raw_urls_found

            post_ids_found << current_post.id
          end
        end
        { result: response, topic_ids_found: topic_ids_found, post_ids_found: post_ids_found }
      rescue StandardError => e
        Rails.logger.error("Chatbot: Error occurred while attempting to retrieve Forum Search results for query '#{query}': #{e.message}")
        { result: I18n.t("chatbot.prompt.function.forum_search.error", query: args[parameters[0][:name]]), topic_ids_found: [], post_ids_found: [] }
      end
    end

    def find_post_and_topic_ids_from_raw_urls(raw)
      post_ids_found = []

      topic_ids_in_raw_topic_links = raw.scan(::DiscourseChatbot::TOPIC_URL_REGEX).flatten
      topic_ids_found = topic_ids_in_raw_topic_links.map(&:to_i)

      post_combos_in_raw_post_links = raw.scan(::DiscourseChatbot::POST_URL_REGEX)

      post_combos_in_raw_post_links.each do |post_combo|
        topic_id_in_text = post_combo[0]
        post_number_in_text = post_combo[1]

        post = ::Post.find_by(topic_id: topic_id_in_text.to_i, post_number: post_number_in_text.to_i)

        post_ids_found << post.id
        topic_ids_found << post.topic_id
      end

      return topic_ids_found, post_ids_found
    end
  end
end

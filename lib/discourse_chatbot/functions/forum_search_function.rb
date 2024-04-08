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
        query = args[parameters[0][:name]]
        number_of_posts = args[parameters[1][:name]].blank? ? 3 : args[parameters[1][:name]]
        number_of_posts = number_of_posts > SiteSetting.chatbot_forum_search_function_max_results ? SiteSetting.chatbot_forum_search_function_max_results : number_of_posts

        process_post_embedding = ::DiscourseChatbot::PostEmbeddingProcess.new
        results = process_post_embedding.semantic_search(query)

        top_results = results[0..(number_of_posts - 1)]

        # exclude if not in scope for embeddings (job hasn't caught up yet)
        top_results.select { |result| !::DiscourseChatbot::PostEmbeddingProcess.new.in_scope(result[:post_id]) || !::DiscourseChatbot::PostEmbeddingProcess.new.is_valid( result[:post_id])}

        if SiteSetting.chatbot_forum_search_function_results_content_type == "topic"
          top_topics = top_results.map { |result| ::Post.find(result[:post_id].to_i).topic_id }.uniq
          response = I18n.t("chatbot.prompt.function.forum_search.answer.topic.summary", number_of_topics: top_topics.length)

          accepted_post_types = SiteSetting.chatbot_include_whispers_in_post_history ? ::DiscourseChatbot::POST_TYPES_INC_WHISPERS : ::DiscourseChatbot::POST_TYPES_REGULAR_ONLY

          top_topics.each_with_index do |topic_id, index|
            top_result = top_results.find do |result|
              post_topic_id = ::Post.find(result[:post_id].to_i).topic_id
              post_topic_id == topic_id
            end
            score = top_result[:score]
            current_topic = ::Topic.find(topic_id)
            url = "https://#{Discourse.current_hostname}/t/slug/#{current_topic.id}"
            title = current_topic.title
            response += I18n.t("chatbot.prompt.function.forum_search.answer.topic.each.topic", url: url, title: title, score: score, rank: index + 1)
            post_number = 1
            while post_number <= SiteSetting.chatbot_forum_search_function_results_posts_count do
              post = ::Post.find_by(topic_id: topic_id, post_number: post_number )
              next if post.deleted_at || !accepted_post_types.includes?(post.post_type)
              break if post.nil?
              response += I18n.t("chatbot.prompt.function.forum_search.answer.topic.each.post", post_number: post_number, username: post.user.username, date: post.created_at, raw: post.raw)
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
          end
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_search.error", query: args[parameters[0][:name]])
      end
    end
  end
end

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
        query = args[parameters[0][:name]]
        number_of_posts = args[parameters[1][:name]].blank? ? 3 : args[parameters[1][:name]]
        number_of_posts = number_of_posts > 10 ? 10 : number_of_posts

        process_post_embedding = ::DiscourseChatbot::PostEmbeddingProcess.new
        results = process_post_embedding.semantic_search(query)

        top_results = results[0..(number_of_posts - 1)]

        response = I18n.t("chatbot.prompt.function.forum_search.answer_summary", number_of_posts: number_of_posts)

        top_results.each_with_index do |result, index|
          current_post = ::Post.find(result.to_i)
          url = "https://#{Discourse.current_hostname}/t/slug/#{current_post.topic_id}/#{current_post.post_number}"
          raw = current_post.raw
          username = User.find(current_post.user_id).username
          date = current_post.created_at.to_date
          response += I18n.t("chatbot.prompt.function.forum_search.answer", url: url, username: username, date: date, raw: raw, rank: index + 1)
        end
        response
      rescue
        I18n.t("chatbot.prompt.function.forum_search.error", query: args[parameters[0][:name]])
      end
    end
  end
end

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
      ]
    end

    def required
      ['query']
    end

    def process(args)
      begin
        super(args)
        query = args[parameters[0][:name]]

        post_embedding = ::DiscourseChatbot::EmbeddingProcess.new
        results = post_embedding.semantic_search(query)

        top_results = results[0..2]
          
        response = I18n.t("chatbot.prompt.function.forum_search.answer_summary")

        top_results.each_with_index do |result, index|
          current_post = ::Post.find(result.to_i)
          url = "#{Discourse.current_hostname}/t/slug/#{current_post.topic_id}/#{current_post.post_number}"
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

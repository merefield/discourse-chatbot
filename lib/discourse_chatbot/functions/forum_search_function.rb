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

        top_result = results[0].to_i

        top_post = ::Post.find(top_result)
        url = "https://localhost:4200/t/slug/#{top_post.topic_id}/#{top_post.post_number}"
        raw = top_post.raw

        I18n.t("chatbot.prompt.function.forum_search.answer", url: url, raw: raw)
      rescue
        I18n.t("chatbot.prompt.function.forum_search.error", query: args[parameters[0][:name]])
      end
    end
  end
end

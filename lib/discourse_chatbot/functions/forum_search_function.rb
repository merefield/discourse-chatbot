# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class ForumSearchFunction < Function

    def name
      'local_forum_search'
    end

    def description
      <<~EOS
        Search the local forum for information that may help you answer the question.  Especially useful when the forum specialises in the subject matter of the query.
        Searching the local forum is preferable to searching google or the internet and should be considered higher priority.

        Input should be a search query.

        Outputs text from the Post and a url you can provide the user with to link them to the relevant Post.
      EOS
    end

    def parameters
      [
        { name: "query", type: String, description: "search query for looking up information on the forum" } ,
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

        "The top Post on the forum with related information can be accessed here: #{url} and the text is #{raw}"
      rescue
        "\"#{args[parameters[0][:name]]}\": my search for this on the forum failed."
      end
    end
  end
end
# frozen_string_literal: true

module ::DiscourseChatbot

  class PgembeddingPostEmbedding < PostEmbedding
    self.table_name = 'chatbot_post_embeddings'
  end

end

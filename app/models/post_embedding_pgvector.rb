# frozen_string_literal: true

module ::DiscourseChatbot

  class PgvectorPostEmbedding < PostEmbedding
    self.table_name = 'chatbot_pgvector_post_embeddings'
  end

end

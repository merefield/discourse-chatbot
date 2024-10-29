# frozen_string_literal: true

module ::DiscourseChatbot
  class TopicTitleEmbedding < ActiveRecord::Base
    self.table_name = 'chatbot_topic_title_embeddings'

    validates :topic_id, presence: true, uniqueness: true
  end
end

# == Schema Information
#
# Table name: chatbot_topic_title_embeddings
#
#  id         :bigint           not null, primary key
#  topic_id   :integer          not null
#  embedding  :vector(1536)     not null
#  model      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_chatbot_topic_title_embeddings_on_topic_id  (topic_id) UNIQUE
#  pgv_hnsw_index_on_chatbot_topic_title_embeddings  (embedding) USING hnsw
#

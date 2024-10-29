# frozen_string_literal: true

module ::DiscourseChatbot
  class TopicEmbeddingsBookmark < ActiveRecord::Base
    self.table_name = 'chatbot_topic_embeddings_bookmark'

    validates :topic_id, presence: true
  end
end

# == Schema Information
#
# Table name: chatbot_topic_embeddings_bookmark
#
#  id         :bigint           not null, primary key
#  topic_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

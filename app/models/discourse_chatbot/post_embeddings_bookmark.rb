# frozen_string_literal: true

module ::DiscourseChatbot
  class PostEmbeddingsBookmark < ActiveRecord::Base
    self.table_name = 'chatbot_post_embeddings_bookmark'

    validates :post_id, presence: true
  end
end

# == Schema Information
#
# Table name: chatbot_post_embeddings_bookmark
#
#  id         :bigint           not null, primary key
#  post_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# frozen_string_literal: true

module ::DiscourseChatbot

  class PostEmbedding < ActiveRecord::Base
    validates :post_id, presence: true, uniqueness: true
  end

end
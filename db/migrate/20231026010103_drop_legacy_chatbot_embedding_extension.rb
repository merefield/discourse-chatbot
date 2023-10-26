# frozen_string_literal: true

class DropLegacyChatbotEmbeddingExtension < ActiveRecord::Migration[7.0]
  def change
    begin
      disable_extension :embedding
    end
  end
end

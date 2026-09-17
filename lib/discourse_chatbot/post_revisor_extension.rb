# frozen_string_literal: true

module DiscourseChatbot
  module PostRevisorExtension
    attr_reader :chatbot_previous_raw

    def revise!(*args, **kwargs, &block)
      # Revision diffs can include earlier grace-period edits, not just this edit.
      @chatbot_previous_raw = @post.raw.dup
      super
    end
  end
end

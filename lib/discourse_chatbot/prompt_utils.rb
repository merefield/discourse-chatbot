# frozen_string_literal: true
module ::DiscourseChatbot

  class PromptUtils

    def self.create_prompt(opts)
      raise "Overwrite me!"
    end

    def self.collect_past_interactions(message_or_post_id)
      raise "Overwrite me!"
    end

    private

    def self.resolve_full_url(url)
      u = URI.parse(url)
      if !SiteSetting.s3_cdn_url.blank?
        SiteSetting.s3_cdn_url + u.path
      else
        Discourse.base_url + u.path
      end
    end
  end
end

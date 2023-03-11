# frozen_string_literal: true
module ::DiscourseChatbot

  class EventEvaluation

    def on_submission(submission)
      raise "Overwrite me!"
    end

    def over_quota(user_id)
      max_quota = 0

      GroupUser.where(user_id: user_id).each do |gu|
        if SiteSetting.chatbot_high_trust_groups.split('|').include? gu.group_id.to_s
          max_quota = SiteSetting.chatbot_quota_high_trust if max_quota < SiteSetting.chatbot_quota_high_trust
        end
        if SiteSetting.chatbot_medium_trust_groups.split('|').include? gu.group_id.to_s
          max_quota = SiteSetting.chatbot_quota_medium_trust if max_quota < SiteSetting.chatbot_quota_medium_trust
        end
        if SiteSetting.chatbot_low_trust_groups.split('|').include? gu.group_id.to_s
          max_quota = SiteSetting.chatbot_quota_low_trust if max_quota < SiteSetting.chatbot_quota_low_trust
        end
      end

      if current_record = UserCustomField.find_by(user_id: user_id, name: CHATBOT_QUERIES_CUSTOM_FIELD)
        current_queries = current_record.value.to_i + 1
        current_record.value = current_queries.to_s
        current_record.save!
      else
        current_queries = 1
        UserCustomField.create!(user_id: user_id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: current_queries)
      end

      current_queries > max_quota
    end

    private

    def invoke_background_job(job_class, opts)
      delay_in_seconds = SiteSetting.chatbot_reply_job_time_delay.to_i
      if delay_in_seconds > 0
        job_class.perform_in(delay_in_seconds.seconds, opts.as_json)
      else
        job_class.perform_async(opts.as_json)
      end
    end

  end
end

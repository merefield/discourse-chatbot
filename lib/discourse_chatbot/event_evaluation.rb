# frozen_string_literal: true
module ::DiscourseChatbot

  class EventEvaluation

    def on_submission(submission)
      raise "Overwrite me!"
    end

    def trust_level(user_id)
      max_trust_level = 0

      GroupUser.where(user_id: user_id).each do |gu|
        if SiteSetting.chatbot_low_trust_groups.split('|').include? gu.group_id.to_s
          max_trust_level = LOW_TRUST_LEVEL if max_trust_level < LOW_TRUST_LEVEL
        end
        if SiteSetting.chatbot_medium_trust_groups.split('|').include? gu.group_id.to_s
          max_trust_level = MEDIUM_TRUST_LEVEL if max_trust_level < MEDIUM_TRUST_LEVEL
        end
        if SiteSetting.chatbot_high_trust_groups.split('|').include? gu.group_id.to_s
          max_trust_level = HIGH_TRUST_LEVEL if max_trust_level < HIGH_TRUST_LEVEL
        end
      end

      max_trust_level.zero? ? nil : ::DiscourseChatbot::TRUST_LEVELS[max_trust_level - 1]
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

      # deal with 'everyone' group
      max_quota = SiteSetting.chatbot_quota_high_trust if SiteSetting.chatbot_high_trust_groups.split('|').include?("0") && max_quota < SiteSetting.chatbot_quota_high_trust
      max_quota = SiteSetting.chatbot_quota_medium_trust if SiteSetting.chatbot_medium_trust_groups.split('|').include?("0") && max_quota < SiteSetting.chatbot_quota_medium_trust
      max_quota = SiteSetting.chatbot_quota_low_trust if SiteSetting.chatbot_low_trust_groups.split('|').include?("0") && max_quota < SiteSetting.chatbot_quota_low_trust

      if current_record = UserCustomField.find_by(user_id: user_id, name: CHATBOT_QUERIES_CUSTOM_FIELD)
        current_queries = current_record.value.to_i + 1
        current_record.value = current_queries.to_s
        current_record.save!
      else
        current_queries = 1
        UserCustomField.create!(user_id: user_id, name: CHATBOT_QUERIES_CUSTOM_FIELD, value: current_queries)
      end

      breach = current_queries > max_quota
      escalate_as_required(user_id) if breach
      breach
    end

    def escalate_as_required(user_id)
      escalation_date = UserCustomField.find_by(name: ::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD, user_id: user_id)

      if SiteSetting.chatbot_quota_reach_escalation_cool_down_period > 0
        if escalation_date.nil? || !SiteSetting.chatbot_quota_reach_escalation_cool_down_period.nil? &&
           escalation_date.value < SiteSetting.chatbot_quota_reach_escalation_cool_down_period.days.ago
           escalate_quota_breach(user_id)
        end
      end
    end

    def escalate_quota_breach(user_id)
      user = User.find_by(id: user_id)
      system_user = User.find_by(username_lower: "system")

      target_group_names = []

      Array(SiteSetting.chatbot_quota_reach_escalation_groups).each do |g|
        unless g.to_i == 0
          target_group_names << Group.find(g.to_i).name
        end
      end

      if !target_group_names.empty?
        target_group_names = target_group_names.join(",")

        default_opts = {
          post_alert_options: { skip_send_email: true },
          raw: I18n.t("chatbot.quota_reached.escalation.message", username: user.username),
          skip_validations: true,
          title: I18n.t("chatbot.quota_reached.escalation.title", username: user.username),
          archetype: Archetype.private_message,
          target_group_names: target_group_names
        }

        post = PostCreator.create!(system_user, default_opts)

        user.custom_fields[::DiscourseChatbot::CHATBOT_QUERIES_QUOTA_REACH_ESCALATION_DATE_CUSTOM_FIELD] = DateTime.now
        user.save_custom_fields
      end
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

# frozen_string_literal: true

module DiscourseChatbot
  class SystemOneClient
    def self.configured?
      [
        SiteSetting.chatbot_system_one_model,
        SiteSetting.chatbot_system_one_url,
        SiteSetting.chatbot_system_one_key,
      ].all?(&:present?)
    end

    def evaluate(state:, questions:)
      request_id = SecureRandom.hex(8)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      payload = {
        model: SiteSetting.chatbot_system_one_model.strip,
        state: state,
        questions: questions,
      }
      log_api_event(request_id: request_id, event: "request", body: payload)
      response =
        Faraday.post(SiteSetting.chatbot_system_one_url.strip) do |request|
          request.headers["Authorization"] = "Bearer #{SiteSetting.chatbot_system_one_key.strip}"
          request.headers["Content-Type"] = "application/json"
          request.options.open_timeout = 5
          request.options.timeout = 15
          request.body = JSON.generate(payload)
        end
      log_api_event(
        request_id: request_id,
        event: "response",
        status: response.status,
        elapsed_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round,
        body: response.body,
      )
      raise "System One returned HTTP #{response.status}" unless response.success?

      JSON.parse(response.body)
    rescue StandardError => error
      log_api_event(request_id: request_id, event: "error", error_class: error.class.name)
      raise
    end

    private

    def log_api_event(**details)
      if !SiteSetting.chatbot_enable_verbose_console_logging &&
           SiteSetting.chatbot_enable_verbose_rails_logging == "off"
        return
      end

      message = "Chatbot: System One #{JSON.generate(details)}"
      key = SiteSetting.chatbot_system_one_key.strip
      if key.present?
        [JSON.generate(key)[1...-1], key].uniq.each do |secret|
          message = message.gsub(secret, "[REDACTED]")
        end
      end
      puts message if SiteSetting.chatbot_enable_verbose_console_logging
      if SiteSetting.chatbot_enable_verbose_rails_logging != "off"
        level = SiteSetting.chatbot_verbose_rails_logging_destination_level
        Rails.logger.public_send(level == "warn" ? :warn : :info, message)
      end
    end
  end
end

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
      response =
        Faraday.post(SiteSetting.chatbot_system_one_url.strip) do |request|
          request.headers["Authorization"] = "Bearer #{SiteSetting.chatbot_system_one_key.strip}"
          request.headers["Content-Type"] = "application/json"
          request.options.open_timeout = 5
          request.options.timeout = 15
          request.body =
            JSON.generate(
              model: SiteSetting.chatbot_system_one_model.strip,
              state: state,
              questions: questions,
            )
        end
      raise "System One returned HTTP #{response.status}" unless response.success?

      JSON.parse(response.body)
    end
  end
end

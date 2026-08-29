# frozen_string_literal: true

require "cgi"

module DiscourseChatbot
  class GeminiEmbeddingClient
    URI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
    OUTPUT_DIMENSIONALITY = 1536

    def initialize(access_token:)
      @access_token = access_token
    end

    def embeddings(parameters:)
      model = parameters.fetch(:model).delete_prefix("models/")
      inputs = Array(parameters.fetch(:input))
      response =
        Faraday.post("#{URI_BASE}/#{CGI.escape(model)}:batchEmbedContents") do |request|
          request.headers["Content-Type"] = "application/json"
          request.headers["x-goog-api-key"] = @access_token
          request.body = JSON.generate(request_body(model, inputs))
        end
      payload = JSON.parse(response.body)
      return payload if payload["error"]

      {
        "data" =>
          Array(payload["embeddings"]).each_with_index.map do |embedding, index|
            { "index" => index, "embedding" => embedding.fetch("values") }
          end,
      }
    end

    private

    def request_body(model, inputs)
      {
        requests:
          inputs.map do |input|
            {
              model: "models/#{model}",
              content: {
                parts: [{ text: input }],
              },
              outputDimensionality: OUTPUT_DIMENSIONALITY,
            }
          end,
      }
    end
  end
end

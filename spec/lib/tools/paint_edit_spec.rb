# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::PaintEdit do
  subject(:paint_edit_tool) { described_class.new }

  describe "#parameters" do
    it "exposes aspect_ratio as an enum override" do
      aspect_ratio_parameter =
        paint_edit_tool.parameters.find { |param| param[:name] == "aspect_ratio" }

      expect(aspect_ratio_parameter[:enum]).to eq(%w[square landscape portrait])
    end
  end

  describe "#resolved_aspect_ratio" do
    it "retains the original aspect ratio when no override is supplied" do
      upload = stub(width: 1024, height: 1536)

      expect(paint_edit_tool.send(:resolved_aspect_ratio, nil, upload)).to eq("portrait")
    end

    it "uses the explicit override when provided" do
      upload = stub(width: 1024, height: 1536)

      expect(paint_edit_tool.send(:resolved_aspect_ratio, "landscape", upload)).to eq("landscape")
    end
  end

  describe "provider request options" do
    it "omits response_format for OpenAI GPT Image edits" do
      options =
        paint_edit_tool.send(
          :edit_options,
          "open_ai",
          "gpt-image-1.5",
          "Make it blue",
          "portrait",
          "1024x1536",
        )

      expect(options).to eq(
        model: "gpt-image-1.5",
        prompt: "Make it blue",
        size: "1024x1536",
        quality: "auto",
      )
    end

    it "maps xAI edit aspect ratios and requests base64 responses" do
      options =
        paint_edit_tool.send(
          :edit_options,
          "x_ai",
          "grok-imagine-image-2.0",
          "Make it blue",
          "portrait",
          "1024x1792",
        )

      expect(options).to eq(
        model: "grok-imagine-image-2.0",
        prompt: "Make it blue",
        aspect_ratio: "9:16",
        response_format: "b64_json",
      )
    end
  end

  describe "xAI image editing" do
    it "uses xAI's JSON API with the shared xAI credential" do
      SiteSetting.chatbot_x_ai_token = "x-ai-image-token"
      SiteSetting.chatbot_image_model_custom_url = "https://images.example.com/v1/"
      request =
        stub_request(:post, "https://images.example.com/v1/images/edits")
          .with do |http_request|
            body = JSON.parse(http_request.body)
            http_request.headers["Authorization"] == "Bearer x-ai-image-token" &&
              body["model"] == "grok-imagine-image-2.0" && body["aspect_ratio"] == "9:16" &&
              body["response_format"] == "b64_json" &&
              body.dig("image", "url").start_with?("data:image/png;base64,")
          end
          .to_return(body: JSON.generate("data" => [{ "b64_json" => "image-data" }]))

      file = Tempfile.new(%w[image .png])
      file.binmode
      file.write("png-data")
      file.close

      response =
        paint_edit_tool.send(
          :x_ai_edit_response,
          {
            model: "grok-imagine-image-2.0",
            prompt: "Make it blue",
            aspect_ratio: "9:16",
            response_format: "b64_json",
          },
          file.path,
          "image/png",
        )

      expect(request).to have_been_requested
      expect(response.dig("data", 0, "b64_json")).to eq("image-data")
    ensure
      file&.unlink
    end
  end
end

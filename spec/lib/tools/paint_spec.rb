# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::Tools::Paint do
  subject(:paint_tool) { described_class.new }

  describe "#parameters" do
    it "exposes aspect_ratio as an enum" do
      aspect_ratio_parameter = paint_tool.parameters.find { |param| param[:name] == "aspect_ratio" }

      expect(aspect_ratio_parameter[:enum]).to eq(%w[square landscape portrait])
    end
  end

  describe ".size_for" do
    it "defaults gpt image models to landscape dimensions" do
      expect(described_class.size_for("gpt-image-1.5", "landscape")).to eq("1536x1024")
    end

    it "supports new gpt image models using gpt image dimensions" do
      expect(described_class.size_for("gpt-image-2", "landscape")).to eq("1536x1024")
    end

    it "supports square dimensions for gpt image models" do
      expect(described_class.size_for("gpt-image-1-mini", "square")).to eq("1024x1024")
    end

    it "supports portrait dimensions for gpt image models" do
      expect(described_class.size_for("gpt-image-1", "portrait")).to eq("1024x1536")
    end

    it "maps dall-e-3 aspect ratios to supported sizes" do
      expect(described_class.size_for("dall-e-3", "landscape")).to eq("1792x1024")
      expect(described_class.size_for("dall-e-3", "square")).to eq("1024x1024")
      expect(described_class.size_for("dall-e-3", "portrait")).to eq("1024x1792")
    end

    it "maps Gemini and xAI image models to compatible fallback sizes" do
      expect(described_class.size_for("gemini-2.5-flash-image", "landscape")).to eq("1536x1024")
      expect(described_class.size_for("grok-imagine-image-2.0", "portrait")).to eq("1024x1792")
    end
  end

  describe ".image_edit_supported?" do
    it "supports OpenAI GPT Image and xAI, but not Gemini image models" do
      SiteSetting.chatbot_image_provider = "open_ai"
      SiteSetting.chatbot_support_picture_creation_model = "gpt-image-1"
      expect(described_class.image_edit_supported?).to eq(true)

      SiteSetting.chatbot_image_provider = "x_ai"
      expect(described_class.image_edit_supported?).to eq(true)

      SiteSetting.chatbot_image_provider = "google_gemini"
      expect(described_class.image_edit_supported?).to eq(false)
    end
  end

  describe "provider request options" do
    it "omits response_format for GPT Image models" do
      options =
        paint_tool.send(
          :generation_options,
          "open_ai",
          "gpt-image-1.5",
          "A lighthouse",
          "landscape",
          "1536x1024",
        )

      expect(options).to eq(
        model: "gpt-image-1.5",
        prompt: "A lighthouse",
        n: 1,
        size: "1536x1024",
        quality: "auto",
        moderation: "low",
      )
    end

    it "requests base64 responses for DALL-E models" do
      options =
        paint_tool.send(
          :generation_options,
          "open_ai",
          "dall-e-3",
          "A lighthouse",
          "landscape",
          "1792x1024",
        )

      expect(options[:response_format]).to eq("b64_json")
    end

    it "uses only Gemini-supported image generation parameters" do
      options =
        paint_tool.send(
          :generation_options,
          "google_gemini",
          "gemini-2.5-flash-image",
          "A lighthouse",
          "landscape",
          "1536x1024",
        )

      expect(options).to eq(
        model: "gemini-2.5-flash-image",
        prompt: "A lighthouse",
        response_format: "b64_json",
        n: 1,
        size: "1536x1024",
      )
    end

    it "uses xAI aspect ratios without OpenAI-only quality parameters" do
      options =
        paint_tool.send(
          :generation_options,
          "x_ai",
          "grok-imagine-image-2.0",
          "A lighthouse",
          "portrait",
          "1024x1792",
        )

      expect(options).to eq(
        model: "grok-imagine-image-2.0",
        prompt: "A lighthouse",
        response_format: "b64_json",
        n: 1,
        aspect_ratio: "9:16",
      )
    end
  end

  describe ".aspect_ratio_for_upload" do
    it "detects portrait uploads" do
      upload = stub(width: 1024, height: 1536)

      expect(described_class.aspect_ratio_for_upload(upload)).to eq("portrait")
    end

    it "detects landscape uploads" do
      upload = stub(width: 1536, height: 1024)

      expect(described_class.aspect_ratio_for_upload(upload)).to eq("landscape")
    end

    it "detects square uploads" do
      upload = stub(width: 1024, height: 1024)

      expect(described_class.aspect_ratio_for_upload(upload)).to eq("square")
    end
  end

  describe ".markdown_for" do
    it "uses the upload dimensions in the rendered markdown" do
      upload = stub(width: 1024, height: 1536, short_url: "upload://portrait.png")

      expect(
        described_class.markdown_for(
          upload: upload,
          description: "portrait image",
          fallback_size: "1536x1024",
        ),
      ).to eq("![portrait image|1024x1536](upload://portrait.png)")
    end
  end
end

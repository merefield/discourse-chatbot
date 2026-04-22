# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::PaintFunction do
  subject(:paint_function) { described_class.new }

  describe "#parameters" do
    it "exposes aspect_ratio as an enum" do
      aspect_ratio_parameter =
        paint_function.parameters.find { |param| param[:name] == "aspect_ratio" }

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

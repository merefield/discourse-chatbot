# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::PaintFunction do
  subject(:paint_function) { described_class.new }

  describe "#parameters" do
    it "exposes aspect_ratio as an enum" do
      aspect_ratio_parameter = paint_function.parameters.find { |param| param[:name] == "aspect_ratio" }

      expect(aspect_ratio_parameter[:enum]).to eq(%w[square landscape portrait])
    end
  end

  describe "#size_for" do
    it "defaults gpt image models to landscape dimensions" do
      expect(paint_function.send(:size_for, "gpt-image-1.5", "landscape")).to eq("1536x1024")
    end

    it "supports square dimensions for gpt image models" do
      expect(paint_function.send(:size_for, "gpt-image-1-mini", "square")).to eq("1024x1024")
    end

    it "supports portrait dimensions for gpt image models" do
      expect(paint_function.send(:size_for, "gpt-image-1", "portrait")).to eq("1024x1536")
    end

    it "maps dall-e-3 aspect ratios to supported sizes" do
      expect(paint_function.send(:size_for, "dall-e-3", "landscape")).to eq("1792x1024")
      expect(paint_function.send(:size_for, "dall-e-3", "square")).to eq("1024x1024")
      expect(paint_function.send(:size_for, "dall-e-3", "portrait")).to eq("1024x1792")
    end
  end
end

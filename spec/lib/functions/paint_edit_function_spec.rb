# frozen_string_literal: true
require_relative "../../plugin_helper"

describe ::DiscourseChatbot::PaintEditFunction do
  subject(:paint_edit_function) { described_class.new }

  describe "#parameters" do
    it "exposes aspect_ratio as an enum override" do
      aspect_ratio_parameter =
        paint_edit_function.parameters.find { |param| param[:name] == "aspect_ratio" }

      expect(aspect_ratio_parameter[:enum]).to eq(%w[square landscape portrait])
    end
  end

  describe "#resolved_aspect_ratio" do
    it "retains the original aspect ratio when no override is supplied" do
      upload = stub(width: 1024, height: 1536)

      expect(paint_edit_function.send(:resolved_aspect_ratio, nil, upload)).to eq("portrait")
    end

    it "uses the explicit override when provided" do
      upload = stub(width: 1024, height: 1536)

      expect(paint_edit_function.send(:resolved_aspect_ratio, "landscape", upload)).to eq(
        "landscape",
      )
    end
  end
end

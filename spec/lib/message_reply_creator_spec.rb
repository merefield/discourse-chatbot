# frozen_string_literal: true
require_relative "../plugin_helper"

describe ::DiscourseChatbot::MessageReplyCreator do
  subject(:reply_creator) { described_class.new({}) }

  describe "#find_upload_from_markdown" do
    it "finds uploads from markdown with non-default dimensions" do
      upload = stub(short_url: "upload://portrait.png")
      ordered_uploads = stub(limit: [upload])
      Upload.expects(:order).with(id: :desc).returns(ordered_uploads)

      result =
        reply_creator.send(
          :find_upload_from_markdown,
          "![portrait image|1024x1536](upload://portrait.png)",
        )

      expect(result).to eq(upload)
    end
  end
end

# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe DiscourseChatbot::Calculator do
  describe ".evaluate" do
    it "evaluates arithmetic, mathematical functions, constants, and dates" do
      now = Time.zone.parse("2026-08-02 12:00:00")

      expect(described_class.evaluate("3 + 4")).to eq(7)
      expect(described_class.evaluate("SQRT(8)")).to be_within(0.000_001).of(Math.sqrt(8))
      expect(described_class.evaluate("PI / 3")).to be_within(0.000_001).of(Math::PI / 3)
      expect(described_class.evaluate("NOW - DURATION(2, days)", now:)).to eq(now - 2.days)
    end

    it "rejects Ruby code and host resource access" do
      expressions = [
        "system('id')",
        "IO.open('/etc/passwd')",
        "File.read('/etc/passwd')",
        "Kernel.eval('1 + 1')",
      ]

      expressions.each do |expression|
        expect { described_class.evaluate(expression) }.to raise_error(
          described_class::InvalidExpression,
        )
      end
    end

    it "rejects expressions that exceed resource limits" do
      expressions = [
        "1" * 33,
        Array.new(51, "1").join("+"),
        "(" * 11 + "1" + ")" * 11,
        "2 ^ 1000",
        "1 << 1000",
        "1" * 513,
      ]

      expressions.each do |expression|
        expect { described_class.evaluate(expression) }.to raise_error(
          described_class::InvalidExpression,
        )
      end
    end

    it "rejects unsupported and non-finite results" do
      expect { described_class.evaluate("{1, 2, 3}") }.to raise_error(
        described_class::InvalidExpression,
      )
      expect { described_class.evaluate("EXP(1000000)") }.to raise_error(
        described_class::InvalidExpression,
      )
    end
  end
end

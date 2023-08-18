# frozen_string_literal: true
require_relative '../../plugin_helper'

describe ::DiscourseChatbot::CalculatorFunction do
  let(:calc) { ::DiscourseChatbot::CalculatorFunction.new }

  it "calculation function returns correct result" do
    args = {'input' => '3 + 4'}

    expect(calc.process(args)).to eq(7)
  end
end

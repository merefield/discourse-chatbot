# frozen_string_literal: true

module DiscourseChatbot
  module ToolSelectionHelpers
    def judgment(choice, probability = 1.0)
      probabilities = { relevant: 0.0, irrelevant: 0.0, unclear: 0.0 }
      probabilities[choice.to_sym] = probability
      probabilities[:unclear] += 1 - probability
      { type: "choice", choice: choice, probabilities: probabilities, confidence: probability }
    end
    def evaluate(prompt: self.prompt, opts: {})
      described_class.new.evaluate(
        tools: tools,
        definitions: definitions,
        prompt: prompt,
        opts: opts,
      )
    end
    def capture_chat(response = final_response)
      client
        .expects(:chat)
        .with do |parameters:|
          requests << parameters.deep_dup
          true
        end
        .returns(response)
    end
  end
end

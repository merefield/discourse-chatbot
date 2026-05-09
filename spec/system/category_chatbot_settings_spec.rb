# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category chatbot settings" do
  fab!(:admin)
  fab!(:category, :category_with_definition)

  let(:category_page) { PageObjects::Pages::Category.new }

  before do
    SiteSetting.chatbot_enabled = true
    SiteSetting.enable_simplified_category_creation = true

    sign_in(admin)
  end

  it "saves chatbot custom fields from the simplified category settings form" do
    category_page.visit_settings(category)

    find(
      ".form-kit__field[data-name='custom_fields.chatbot_auto_response_additional_prompt']",
    ).find(".form-kit__control-textarea").fill_in(with: "Use the category-specific response tone.")

    category_page.save_settings

    expect(category.reload.custom_fields["chatbot_auto_response_additional_prompt"]).to eq(
      "Use the category-specific response tone.",
    )
  end
end

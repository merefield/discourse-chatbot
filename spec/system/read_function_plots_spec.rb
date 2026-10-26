# frozen_string_literal: true

require_relative "page_objects/components/function_plots"

RSpec.describe "Read function plots" do
  fab!(:user)
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:graphs) { PageObjects::Components::FunctionPlots.new }

  before do
    enable_current_plugin
    SiteSetting.chatbot_enabled = true
    SiteSetting.chatbot_function_plot_enabled = true
    sign_in(user)
  end

  it "lets readers see mathematical explanations with multiple locally rendered curves" do
    polynomial =
      DiscourseChatbot::FunctionPlot.markdown(
        "expressions" => "x^2-4",
        "title" => "Roots of a quadratic",
      )
    trig =
      DiscourseChatbot::FunctionPlot.markdown(
        "expressions" => "sin(x)\ncos(x)",
        "y_min" => -2,
        "y_max" => 2,
      )
    Fabricate(
      :post,
      topic: topic,
      raw: "The roots of $x^2-4=0$ are $x=\\pm2$.\n\n#{polynomial}\n\n#{trig}",
    )

    topic_page.visit_topic(topic)

    expect(topic_page).to have_content("The roots of")
    expect(graphs).to have_rendered_graphs(count: 2)
    expect(topic_page).to have_content("Roots of a quadratic")

    page.refresh
    expect(graphs).to have_rendered_graphs(count: 2)
  end

  it "shows a useful fallback for an unsupported expression without executing it" do
    Fabricate(
      :post,
      topic: topic,
      raw: "```function-plot\n{\"functions\":[\"window.alert(1)\"]}\n```",
    )

    topic_page.visit_topic(topic)

    expect(graphs).to have_error
    expect(topic_page).to have_content(I18n.t("js.chatbot.function_plot.fallback"))
  end

  it "preserves gaps in the domain and handles an entirely undefined curve" do
    graph = DiscourseChatbot::FunctionPlot.markdown("expressions" => "sqrt(x^2-1)\nsqrt(-1)")
    Fabricate(:post, topic: topic, raw: graph)

    topic_page.visit_topic(topic)

    expect(graphs).to have_separate_domain_segments
    expect(graphs).to have_no_error
  end
end

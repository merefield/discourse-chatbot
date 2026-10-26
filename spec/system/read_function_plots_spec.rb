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

  it "traces visible curves and snaps to axes and series intersections" do
    graph =
      DiscourseChatbot::FunctionPlot.markdown(
        "expressions" => "x^2\nsqrt(x)",
        "x_min" => -2,
        "x_max" => 2,
        "y_min" => -1,
        "y_max" => 5,
      )
    Fabricate(:post, topic: topic, raw: graph)
    topic_page.visit_topic(topic)

    expect(graphs).to have_rendered_graphs(count: 1)
    graphs.move_over_2d_plot(relative_x: 0.755)
    expect(graphs).to have_trace_points(count: 2)
    expect(graphs).to have_trace_values(count: 2)
    expect(graphs.trace_coordinates).to eq([[1, 1], [1, 1]])
    expect(graphs.trace_point_positions.uniq.length).to eq(1)
    initial_positions = graphs.trace_point_positions

    graphs.move_over_2d_plot(relative_x: 0.875)
    try_until_success { expect(graphs.trace_coordinates.first[0]).to be_within(0.03).of(1.5) }
    expect(graphs.trace_coordinates.first[1]).to be_within(0.04).of(2.25)
    expect(graphs.trace_point_positions).not_to eq(initial_positions)

    graphs.move_over_2d_plot(relative_x: 0.25)
    expect(graphs).to have_trace_points(count: 1)
    expect(graphs).to have_trace_values(count: 1)
    expect(graphs.trace_coordinates.last).to be_nil

    graphs.move_over_2d_plot(relative_x: 0.502)
    expect(graphs).to have_trace_points(count: 2)
    expect(graphs).to have_trace_values(count: 2)
    expect(graphs.trace_coordinates.first).to eq([0, 0])
    expect(graphs.trace_coordinates[1]).to eq([0, 0])

    graphs.leave_plot
    expect(graphs).to have_trace_points(count: 0)
    expect(graphs).to have_trace_values(count: 0)
  end

  it "preserves gaps in the domain and handles an entirely undefined curve" do
    graph = DiscourseChatbot::FunctionPlot.markdown("expressions" => "sqrt(x^2-1)\nsqrt(-1)")
    Fabricate(:post, topic: topic, raw: graph)

    topic_page.visit_topic(topic)

    expect(graphs).to have_separate_domain_segments
    expect(graphs).to have_no_error
  end

  it "renders the additional plot families locally" do
    definitions = [
      { "plot_type" => "implicit", "expressions" => "x^2+y^2-4", "title" => "Circle" },
      {
        "plot_type" => "parametric",
        "expressions" => "cos(t); sin(t)",
        "title" => "Parametric circle",
      },
      { "plot_type" => "polar", "expressions" => "2*cos(3*theta)", "title" => "Rose" },
      { "plot_type" => "points", "expressions" => "0,1\n2,3\n3,2", "title" => "Scatter" },
      {
        "plot_type" => "polyline",
        "expressions" => "0,1\n2,3\n3,2",
        "title" => "Connected points",
      },
      { "plot_type" => "vector", "expressions" => "3,2\n1,1,-2,1", "title" => "Vectors" },
    ]
    raw = definitions.map { |args| DiscourseChatbot::FunctionPlot.markdown(args) }.join("\n\n")
    Fabricate(:post, topic: topic, raw: raw)

    topic_page.visit_topic(topic)

    expect(graphs).to have_rendered_graphs(count: 6)
    expect(graphs).to have_implicit_curve
    expect(graphs).to have_scatter_points(count: 3)
    expect(graphs).to have_vector_arrows(count: 2)
    expect(graphs).to have_no_error
    expect(graphs).to have_finite_paths
  end

  it "stops an expensive implicit definition with a useful fallback" do
    graph =
      DiscourseChatbot::FunctionPlot.markdown("plot_type" => "implicit", "expressions" => "x-x+y-y")
    Fabricate(:post, topic: topic, raw: graph)

    topic_page.visit_topic(topic)

    expect(graphs).to have_error
    expect(graphs).to have_no_visible_canvas
    expect(topic_page).to have_content(I18n.t("js.chatbot.function_plot.fallback"))
  end

  it "lets readers pan and zoom a curve without scrolling the page" do
    graph = DiscourseChatbot::FunctionPlot.markdown("expressions" => "sin(x)")
    Fabricate(:post, topic: topic, raw: graph + "\n\n" + ("More about the graph.\n\n" * 30))
    topic_page.visit_topic(topic)

    expect(graphs).to have_rendered_graphs(count: 1)
    original_path = graphs.curve_path
    graphs.pan_plot
    try_until_success { expect(graphs.curve_path).not_to eq(original_path) }
    panned_path = graphs.curve_path
    graphs.zoom_plot
    try_until_success { expect(graphs.curve_path).not_to eq(panned_path) }
    zoomed_path = graphs.curve_path
    scroll_position = graphs.page_scroll_position
    graphs.zoom_plot(delta_y: 300)
    try_until_success { expect(graphs.curve_path).not_to eq(zoomed_path) }
    expect(graphs.page_scroll_position).to eq(scroll_position)
    expect(graphs).to have_no_error
    graphs.scroll_outside_plot
    try_until_success { expect(graphs.page_scroll_position).to be > scroll_position }
  end
end

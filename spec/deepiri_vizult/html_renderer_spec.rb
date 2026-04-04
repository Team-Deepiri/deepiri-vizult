# frozen_string_literal: true

require "spec_helper"
require "deepiri_vizult/graph"
require "deepiri_vizult/renderers/html_renderer"

RSpec.describe DeepiriVizult::Renderers::HtmlRenderer do
  it "renders viewer shell with stats and version" do
    g = DeepiriVizult::Graph.new
    g.add_node(id: "repo:x", type: :repo, label: "x")

    html = described_class.new(g).render
    expect(html).to include(DeepiriVizult::VERSION)
    expect(html).to include("<strong>1</strong>")
    expect(html).to include("<strong>0</strong>")
    expect(html).to include("vizult")
    expect(html).to include("cytoscape")
  end
end

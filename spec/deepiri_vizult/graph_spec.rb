# frozen_string_literal: true

require "spec_helper"
require "deepiri_vizult/graph"

RSpec.describe DeepiriVizult::Graph do
  it "adds nodes and edges" do
    g = described_class.new
    g.add_node(id: "service:a", type: :service, label: "a")
    g.add_node(id: "service:b", type: :service, label: "b")
    g.add_edge(from: "service:a", to: "service:b", type: :http_call, confidence: :high, source_file: "x.ts", line_number: 1)
    expect(g.nodes.size).to eq(2)
    expect(g.edges.size).to eq(1)
    expect(g.edges_for("service:a").size).to eq(1)
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe DeepiriVizult::Graph do
  it "merge_prefixed! copies nodes and edges with prefix" do
    a = described_class.new
    a.add_node(id: "service:x", type: :service, label: "x")
    a.add_node(id: "service:y", type: :service, label: "y")
    a.add_edge(from: "service:x", to: "service:y", type: :http_call, confidence: :high)

    b = described_class.new
    b.merge_prefixed!(a, prefix: "p_")

    expect(b.nodes["p_service:x"]).to be_truthy
    expect(b.nodes["p_service:y"]).to be_truthy
    expect(b.edges.any? { |e| e[:from] == "p_service:x" && e[:to] == "p_service:y" }).to be true
  end
end

# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"
require "deepiri_vizult/graph"
require "deepiri_vizult/manifest_sibling_refs"

RSpec.describe DeepiriVizult::ManifestSiblingRefs do
  let(:parent) { Dir.mktmpdir("vizult-manifest") }
  let(:main) { File.join(parent, "main") }
  let(:other) { File.join(parent, "other") }

  after { FileUtils.remove_entry(parent) }

  before do
    FileUtils.mkdir_p(File.join(main, ".git"))
    FileUtils.mkdir_p(File.join(other, ".git"))
  end

  it "adds manifest_ref from package.json file:../ sibling" do
    graph = DeepiriVizult::Graph.new
    graph.add_node(id: "repo:main", type: :repo, label: "main", metadata: { path: main })
    graph.add_node(id: "repo:other", type: :repo, label: "other", metadata: { path: other })

    File.write(File.join(main, "package.json"), <<~JSON)
      {
        "dependencies": { "x": "file:../other" }
      }
    JSON

    described_class.apply(graph, main)

    mr = graph.edges.select { |e| e[:type] == :manifest_ref }
    expect(mr.size).to eq(1)
    expect(mr.first[:from]).to eq("repo:main")
    expect(mr.first[:to]).to eq("repo:other")
    expect(mr.first[:confidence]).to eq(:medium)
  end

  it "adds manifest_ref from go.mod replace directive" do
    graph = DeepiriVizult::Graph.new
    graph.add_node(id: "repo:main", type: :repo, label: "main", metadata: { path: main })
    graph.add_node(id: "repo:other", type: :repo, label: "other", metadata: { path: other })

    File.write(File.join(main, "go.mod"), "module x\n\nreplace y => ../other\n")

    described_class.apply(graph, main)

    mr = graph.edges.select { |e| e[:type] == :manifest_ref }
    expect(mr.size).to eq(1)
    expect(mr.first[:to]).to eq("repo:other")
  end
end

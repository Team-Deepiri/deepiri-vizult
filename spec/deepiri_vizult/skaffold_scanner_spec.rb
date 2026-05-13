# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"
require "deepiri_vizult/graph"
require "deepiri_vizult/service_registry"
require "deepiri_vizult/scanners/skaffold_scanner"

RSpec.describe DeepiriVizult::Scanners::SkaffoldScanner do
  let(:tmpdir) { Dir.mktmpdir("vizult-skaffold") }

  after do
    FileUtils.remove_entry(tmpdir)
  end

  it "parses skaffold build artifacts and registers them as services" do
    FileUtils.mkdir_p(File.join(tmpdir, "svc"))
    File.write(File.join(tmpdir, "skaffold.yaml"), <<~YAML)
      apiVersion: skaffold/v4beta7
      kind: Config
      build:
        artifacts:
          - image: myorg/api-service
            context: ./svc
      deploy:
        kubectl:
          manifests:
            - k8s/deploy.yaml
    YAML

    g = DeepiriVizult::Graph.new
    g.add_node(id: "repo:#{File.basename(tmpdir)}", type: :repo, label: File.basename(tmpdir), metadata: {})
    reg = DeepiriVizult::ServiceRegistry.new

    described_class.new(root: tmpdir, graph: g, registry: reg, max_depth: 8).scan

    expect(reg.services.key?("api-service")).to be true
    expect(g.node?("service:api-service")).to be true
    expect(g.nodes.keys.none? { |k| k.start_with?("skaffold:") }).to be true
  end
end

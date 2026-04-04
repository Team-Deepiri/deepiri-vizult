# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"
require "deepiri_vizult/graph"
require "deepiri_vizult/service_registry"
require "deepiri_vizult/scanners/compose_scanner"

RSpec.describe DeepiriVizult::Scanners::ComposeScanner do
  let(:tmpdir) { Dir.mktmpdir("vizult") }

  after do
    FileUtils.remove_entry(tmpdir)
  end

  it "parses docker-compose services" do
    File.write(File.join(tmpdir, "docker-compose.yml"), <<~YAML)
      services:
        web:
          build: ./web
          depends_on:
            - api
        api:
          image: api:latest
          environment:
            DATABASE_URL: postgres://db:5432/app
        db:
          image: postgres:15
    YAML
    FileUtils.mkdir_p(File.join(tmpdir, "web"))

    g = DeepiriVizult::Graph.new
    reg = DeepiriVizult::ServiceRegistry.new
    described_class.new(root: tmpdir, graph: g, registry: reg, max_depth: 5).scan

    expect(reg.services.key?("web")).to be true
    expect(reg.services.key?("api")).to be true
    expect(g.edges.any? { |e| e[:type] == :depends_on && e[:from] == "service:web" }).to be true
  end
end

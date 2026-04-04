# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"

RSpec.describe DeepiriVizult::Scanner do
  let(:tmpdir) { Dir.mktmpdir("vizult-full") }

  after do
    FileUtils.remove_entry(tmpdir)
  end

  it "runs full pipeline on a minimal project" do
    File.write(File.join(tmpdir, "docker-compose.yml"), <<~YAML)
      services:
        api:
          build: ./api
          environment:
            AUTH_URL: http://auth:5001
        auth:
          image: auth:latest
    YAML
    FileUtils.mkdir_p(File.join(tmpdir, "api"))
    File.write(File.join(tmpdir, "api", "client.ts"), <<~TS)
      const u = process.env.AUTH_URL || 'http://auth:5001';
      fetch(u + '/health');
    TS

    scan = described_class.new(
      root: tmpdir,
      siblings: false,
      submodules: false,
      siblings_scan: false,
      infer_org_links: false,
      max_depth: 8,
      org: nil
    )
    scan.run

    expect(scan.registry.services.key?("api")).to be true
    expect(scan.registry.services.key?("auth")).to be true
    expect(scan.graph.edges.any? { |e| e[:type] == :depends_on }).to be false # no depends_on in fixture
    expect(scan.graph.nodes.size).to be >= 2
  end
end

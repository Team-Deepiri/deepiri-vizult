# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'spec_helper'

RSpec.describe 'siblings_scan merge' do
  let(:parent) { Dir.mktmpdir('vizult-sibscan') }
  let(:main) { File.join(parent, 'main') }
  let(:sib) { File.join(parent, 'sib') }

  after { FileUtils.remove_entry(parent) }

  before do
    FileUtils.mkdir_p(File.join(main, '.git'))
    FileUtils.mkdir_p(File.join(sib, '.git'))
    File.write(File.join(main, 'docker-compose.yml'), <<~YAML)
      services:
        api:
          image: api:latest
    YAML
    File.write(File.join(sib, 'docker-compose.yml'), <<~YAML)
      services:
        worker:
          image: worker:latest
    YAML
  end

  it 'merges prefixed subgraph and scan_overlay bridge' do
    scan = DeepiriVizult::Scanner.new(
      root: main,
      siblings: true,
      submodules: false,
      siblings_scan: true,
      infer_org_links: false,
      max_depth: 8,
      org: nil
    )
    scan.run

    prefixed = scan.graph.nodes.keys.select { |k| k.start_with?('sb') && k.include?('service:') }
    expect(prefixed).not_to be_empty

    overlay = scan.graph.edges.select { |e| e[:type] == :scan_overlay }
    expect(overlay).not_to be_empty
    expect(overlay.first[:metadata][:merged_scan]).to be true
  end
end

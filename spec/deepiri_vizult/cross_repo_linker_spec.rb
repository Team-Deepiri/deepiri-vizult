# frozen_string_literal: true

require 'fileutils'
require 'spec_helper'
require 'deepiri_vizult/graph'
require 'deepiri_vizult/cross_repo_linker'

RSpec.describe DeepiriVizult::CrossRepoLinker do
  describe '.path_exists?' do
    let(:graph) { DeepiriVizult::Graph.new }

    it 'returns true when an undirected path exists' do
      graph.add_node(id: 'a', type: :repo, label: 'a')
      graph.add_node(id: 'b', type: :repo, label: 'b')
      graph.add_node(id: 'c', type: :repo, label: 'c')
      graph.add_edge(from: 'a', to: 'b', type: :contains, confidence: :high)

      expect(described_class.path_exists?(graph, 'a', 'b')).to be true
      expect(described_class.path_exists?(graph, 'a', 'c')).to be false
    end
  end

  describe '.apply!' do
    let(:parent) { Dir.mktmpdir('vizult-xrepo') }
    let(:main) { File.join(parent, 'main') }
    let(:sib) { File.join(parent, 'sib') }

    after { FileUtils.remove_entry(parent) }

    before do
      FileUtils.mkdir_p(File.join(main, '.git'))
      FileUtils.mkdir_p(File.join(sib, '.git'))
    end

    it 'adds adjacent_clone from root repo to sibling when no connecting path' do
      graph = DeepiriVizult::Graph.new
      graph.add_node(id: 'repo:main', type: :repo, label: 'main', metadata: { path: main })
      graph.add_node(id: 'repo:sib', type: :repo, label: 'sib', metadata: { path: sib })

      described_class.apply!(graph, main, siblings: true, infer_org_links: false)

      ac = graph.edges.select { |e| e[:type] == :adjacent_clone }
      expect(ac.size).to eq(1)
      expect(ac.first[:from]).to eq('repo:main')
      expect(ac.first[:to]).to eq('repo:sib')
      expect(ac.first[:confidence]).to eq(:low)
      expect(ac.first.dig(:metadata, :inference)).to be true
    end

    it 'adds same_org between sibling repo pairs sharing org when no path exists' do
      third = File.join(parent, 'third')
      FileUtils.mkdir_p(File.join(third, '.git'))

      graph = DeepiriVizult::Graph.new
      graph.add_node(id: 'repo:sib', type: :repo, label: 'sib', metadata: { path: sib, org: 'Acme' })
      graph.add_node(id: 'repo:third', type: :repo, label: 'third', metadata: { path: third, org: 'Acme' })

      described_class.apply_same_org!(graph, main)

      so = graph.edges.select { |e| e[:type] == :same_org }
      expect(so.size).to eq(1)
      expect(so.first.dig(:metadata, :inference)).to be true
      expect([so.first[:from], so.first[:to]].sort).to eq(%w[repo:sib repo:third])
    end
  end
end

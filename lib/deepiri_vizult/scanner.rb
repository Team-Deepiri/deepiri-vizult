# frozen_string_literal: true

require 'pathname'
require 'zlib'

require_relative 'submodule_paths'
require_relative 'sibling_roots'
require_relative 'cross_repo_linker'
require_relative 'manifest_sibling_refs'

module DeepiriVizult
  # Orchestrates all scanners in order per plan.
  class Scanner
    def initialize(root:, siblings: true, submodules: false, siblings_scan: false, infer_org_links: false,
                   max_depth: 12, org: nil, finalize: true)
      @root = Pathname.new(root).expand_path
      @siblings = siblings
      @submodules = submodules
      @siblings_scan = siblings_scan
      @infer_org_links = infer_org_links
      @max_depth = max_depth
      @org = org
      @finalize = finalize
      @graph = Graph.new
      @registry = ServiceRegistry.new
    end

    attr_reader :graph, :registry, :root

    def run
      run_core_scanners
      merge_submodule_graphs! if @submodules
      merge_sibling_graphs! if @siblings_scan && @finalize
      finalize_graph! if @finalize
      self
    end

    private

    def run_core_scanners
      Scanners::GitScanner.new(root: @root, graph: @graph, siblings: @siblings).scan
      Scanners::ComposeScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth).scan
      Scanners::K8sScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth + 2).scan
      Scanners::SkaffoldScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth + 2).scan
      Scanners::PackageScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth + 3).scan
      Scanners::SourceScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth).scan
      Scanners::StreamScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth).scan
      Scanners::DbScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth).scan
      Scanners::SocketScanner.new(root: @root, graph: @graph, registry: @registry, max_depth: @max_depth).scan
    end

    def finalize_graph!
      fetch_org_repos if @org
      ManifestSiblingRefs.apply(@graph, @root)
      CrossRepoLinker.apply!(
        @graph,
        @root,
        siblings: @siblings,
        infer_org_links: @infer_org_links
      )
    end

    def merge_submodule_graphs!
      SubmodulePaths.list(@root).each do |sub_path|
        next if sub_path.expand_path == @root.expand_path
        next unless sub_path.to_s.start_with?(@root.to_s)

        prefix = submodule_prefix(sub_path)
        child = Scanner.new(
          root: sub_path,
          siblings: false,
          submodules: false,
          siblings_scan: false,
          infer_org_links: false,
          max_depth: @max_depth,
          org: nil,
          finalize: false
        )
        child.run
        @graph.merge_prefixed!(child.graph, prefix: prefix)
      end
    end

    def merge_sibling_graphs!
      SiblingRoots.list(@root).each do |sib_path|
        prefix = sibling_prefix(sib_path)
        child = Scanner.new(
          root: sib_path,
          siblings: false,
          submodules: false,
          siblings_scan: false,
          infer_org_links: false,
          max_depth: @max_depth,
          org: nil,
          finalize: false
        )
        child.run
        @graph.merge_prefixed!(child.graph, prefix: prefix)
        bridge_sibling_overlay!(prefix, sib_path.basename.to_s)
      end
    end

    def submodule_prefix(path)
      format('sm%x_', Zlib.crc32(path.to_s) & 0xffffffff)
    end

    def sibling_prefix(path)
      format('sb%x_', Zlib.crc32(path.to_s) & 0xffffffff)
    end

    def bridge_sibling_overlay!(prefix, basename_str)
      canon = "repo:#{basename_str}"
      pref = "#{prefix}repo:#{basename_str}"
      return unless @graph.node?(canon) && @graph.node?(pref)
      return if overlay_edge?(@graph, canon, pref)

      @graph.add_edge(
        from: canon,
        to: pref,
        type: :scan_overlay,
        confidence: :high,
        source_file: nil,
        line_number: nil,
        metadata: { merged_scan: true }
      )
    end

    def overlay_edge?(graph, a, b)
      graph.edges.any? do |e|
        (e[:from] == a && e[:to] == b) || (e[:from] == b && e[:to] == a)
      end
    end

    def fetch_org_repos
      return unless system('command -v gh >/dev/null 2>&1')

      out = `gh api "orgs/#{@org}/repos" --paginate --jq '.[].name' 2>/dev/null`
      return if out.nil? || out.strip.empty?

      out.each_line do |line|
        name = line.strip
        next if name.empty?

        rid = "repo:#{name}"
        next if @graph.node?(rid)

        @graph.add_node(
          id: rid,
          type: :repo,
          label: name,
          metadata: { remote_only: true, org: @org }
        )
      end
    rescue StandardError => e
      warn "vizult: org fetch failed: #{e.message}"
    end
  end
end

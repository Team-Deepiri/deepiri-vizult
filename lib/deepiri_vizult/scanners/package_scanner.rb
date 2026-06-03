# frozen_string_literal: true

require 'json'
require 'set'
require 'pathname'

module DeepiriVizult
  module Scanners
    class PackageScanner
      def initialize(root:, graph:, registry:, max_depth: 15)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
        @known_names = build_known_names
      end

      def scan
        package_json_files.each { |f| scan_package_json(f) }
        gemfiles.each { |f| scan_gemfile(f) }
      end

      private

      def build_known_names
        names = Set.new
        @registry.services.each_key { |k| names << k }
        @graph.nodes.each_value do |n|
          names << n[:label] if n[:type] == :repo
        end
        names
      end

      def package_json_files
        glob_package('package.json')
      end

      def gemfiles
        glob_package('Gemfile')
      end

      def glob_package(basename)
        files = []
        Dir.glob(@root.join("**/#{basename}"), File::FNM_DOTMATCH).each do |p|
          next unless File.file?(p)

          rel = Pathname.new(p).relative_path_from(@root)
          next if rel.to_s.split(File::SEPARATOR).size > @max_depth
          next if rel.to_s.include?('node_modules')

          files << Pathname.new(p)
        end
        files
      end

      def scan_package_json(path)
        data = JSON.parse(File.read(path, encoding: 'UTF-8'))
        deps = {}
        %w[dependencies devDependencies peerDependencies].each do |k|
          deps.merge!(data[k] || {})
        end
        pkg = path.dirname.basename.to_s
        from_id = "package:#{path.relative_path_from(@root)}"

        deps.each_key do |name|
          next unless internal_package?(name)

          to = resolve_internal_target(name)
          next unless to

          ensure_package_node(from_id, pkg, path)
          @graph.add_edge(
            from: from_id,
            to: to,
            type: :imports,
            confidence: :medium,
            source_file: path.to_s,
            metadata: { package: name }
          )
        end
      rescue JSON::ParserError, StandardError
        nil
      end

      def internal_package?(name)
        base = name.split(%r{/}).last
        @known_names.include?(name) || @known_names.include?(base) || @registry.services.key?(base)
      end

      def resolve_internal_target(name)
        base = name.split(%r{/}).last
        return "service:#{base}" if @registry.services.key?(base)

        rid = "repo:#{base}"
        return rid if @graph.node?(rid)

        nil
      end

      def scan_gemfile(path)
        text = File.read(path, encoding: 'UTF-8')
        text.scan(/gem\s+["']([^"']+)["']/).flatten.each do |g|
          next unless internal_package?(g)

          to = resolve_internal_target(g)
          next unless to

          from_id = "package:#{path.relative_path_from(@root)}"
          ensure_package_node(from_id, 'gem', path)
          @graph.add_edge(from: from_id, to: to, type: :imports, confidence: :low, source_file: path.to_s,
                          metadata: { gem: g })
        end
      end

      # Adds the endpoint node for this package manifest (if not present) and anchors it under the
      # deepest repo node whose path is a prefix of the manifest's location. Without this anchor,
      # `package:*` endpoints float free of any repo and read as stray nodes in the viewer.
      def ensure_package_node(from_id, label, path)
        return if @graph.node?(from_id)

        @graph.add_node(id: from_id, type: :endpoint, label: label, metadata: { file: path.to_s })

        owner = owning_repo_id(path)
        return unless owner
        return if @graph.edges.any? { |e| e[:from] == owner && e[:to] == from_id && e[:type] == :contains }

        @graph.add_edge(
          from: owner,
          to: from_id,
          type: :contains,
          confidence: :high,
          source_file: path.to_s
        )
      end

      def owning_repo_id(path)
        abs = path.expand_path.to_s
        best_id = nil
        best_len = -1
        @graph.nodes.each do |id, node|
          next unless node[:type] == :repo

          rp = node.dig(:metadata, :path)
          next if rp.nil? || rp.empty?

          rp_abs = Pathname.new(rp).expand_path.to_s
          next unless abs.start_with?(rp_abs + File::SEPARATOR) || abs == rp_abs

          if rp_abs.length > best_len
            best_len = rp_abs.length
            best_id = id
          end
        end
        best_id || ("repo:#{@root.basename}" if @graph.node?("repo:#{@root.basename}"))
      end
    end
  end
end

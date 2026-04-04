# frozen_string_literal: true

require "json"
require "set"
require "pathname"

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
        @graph.nodes.each do |id, n|
          names << n[:label] if n[:type] == :repo
        end
        names
      end

      def package_json_files
        glob_package("package.json")
      end

      def gemfiles
        glob_package("Gemfile")
      end

      def glob_package(basename)
        files = []
        Dir.glob(@root.join("**/#{basename}"), File::FNM_DOTMATCH).each do |p|
          next unless File.file?(p)

          rel = Pathname.new(p).relative_path_from(@root)
          next if rel.to_s.split(File::SEPARATOR).size > @max_depth
          next if rel.to_s.include?("node_modules")

          files << Pathname.new(p)
        end
        files
      end

      def scan_package_json(path)
        data = JSON.parse(File.read(path, encoding: "UTF-8"))
        deps = {}
        %w[dependencies devDependencies peerDependencies].each do |k|
          deps.merge!(data[k] || {})
        end
        pkg = path.dirname.basename.to_s
        from_id = "package:#{path.relative_path_from(@root)}"

        deps.each do |name, _version|
          next unless internal_package?(name)

          to = resolve_internal_target(name)
          next unless to

          @graph.add_node(id: from_id, type: :endpoint, label: pkg, metadata: { file: path.to_s }) unless @graph.node?(from_id)
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
        base = name.split(%r{[/]}).last
        @known_names.include?(name) || @known_names.include?(base) || @registry.services.key?(base)
      end

      def resolve_internal_target(name)
        base = name.split(%r{[/]}).last
        return "service:#{base}" if @registry.services.key?(base)

        rid = "repo:#{base}"
        return rid if @graph.node?(rid)

        nil
      end

      def scan_gemfile(path)
        text = File.read(path, encoding: "UTF-8")
        text.scan(/gem\s+["']([^"']+)["']/).flatten.each do |g|
          next unless internal_package?(g)

          to = resolve_internal_target(g)
          next unless to

          from_id = "package:#{path.relative_path_from(@root)}"
          @graph.add_node(id: from_id, type: :endpoint, label: "gem", metadata: { file: path.to_s }) unless @graph.node?(from_id)
          @graph.add_edge(from: from_id, to: to, type: :imports, confidence: :low, source_file: path.to_s, metadata: { gem: g })
        end
      end
    end
  end
end

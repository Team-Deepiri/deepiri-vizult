# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  module Scanners
    class SocketScanner
      PATTERNS = [
        /socket\.io-client/,
        /from\s+['"]socket\.io['"]/,
        /new\s+WebSocket\s*\(/,
        /io\.connect\s*\(/,
        /proxy.*socket\.io/i
      ].freeze

      def initialize(root:, graph:, registry:, max_depth: 12)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
        @path_resolver = PathResolver.new(registry)
      end

      def scan
        files.each { |f| scan_file(f) }
      end

      private

      def files
        exts = %w[.ts .tsx .js .jsx .vue .py]
        ProjectFiles.list(@root).select do |p|
          exts.include?(p.extname) && within_depth?(p)
        end
      end

      def within_depth?(path)
        path.relative_path_from(@root).to_s.split(File::SEPARATOR).size <= @max_depth
      rescue ArgumentError
        true
      end

      def scan_file(path)
        text = File.read(path, encoding: "UTF-8")
        return unless PATTERNS.any? { |re| text.match?(re) }

        owner = @path_resolver.owning_service(path, @root)
        from_id = owner ? "service:#{owner}" : "repo:#{@root.basename}"

        @graph.add_node(id: "endpoint:websocket", type: :endpoint, label: "WebSocket", metadata: {}) unless @graph.node?("endpoint:websocket")

        lines = text.lines
        lines.each_with_index do |line, idx|
          next unless PATTERNS.any? { |re| line.match?(re) }

          @graph.add_edge(
            from: from_id,
            to: "endpoint:websocket",
            type: :websocket,
            confidence: :low,
            source_file: path.to_s,
            line_number: idx + 1
          )
        end
      rescue StandardError
        nil
      end
    end
  end
end

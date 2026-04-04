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

      SKIP_DIRS = %w[node_modules vendor/bundle .git].freeze

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
        out = []
        Dir.glob(@root.join("**/*"), File::FNM_DOTMATCH).each do |p|
          next unless File.file?(p)

          rel = Pathname.new(p).relative_path_from(@root)
          next if rel.to_s.split(File::SEPARATOR).size > @max_depth
          next if rel.to_s.split(File::SEPARATOR).any? { |d| SKIP_DIRS.include?(d) }

          next unless exts.include?(File.extname(p))

          out << Pathname.new(p)
        end
        out
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

# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  module Scanners
    class StreamScanner
      PUBLISH = [
        /\.publish\s*\(\s*['"]([^'"]+)['"]/,
        /xadd\s*\(\s*['"]([^'"]+)['"]/i,
        /XADD\s+['"]([^'"]+)['"]/i,
        /producer\.send\s*\(\s*['"]([^'"]+)['"]/,
        /send\s*\(\s*['"]([^'"]+)['"]\s*,/, # kafka generic
        %r|topics?\s*[=:]\s*['"]([^'"]+)['"]|
      ].freeze

      CONSUME = [
        /xreadgroup\s+[^'"]*['"]([^'"]+)['"]/i,
        /xread\s+[^'"]*['"]([^'"]+)['"]/i,
        /subscribe\s*\(\s*['"]([^'"]+)['"]/,
        /consumer\.subscribe\s*\(\s*\{?\s*topic[s]?\s*:\s*['"]([^'"]+)['"]/,
        /from\s+['"]([^'"]+)['"]\s*# kafka/i
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
        exts = %w[.ts .tsx .js .jsx .py .go .rb]
        files = []
        Dir.glob(@root.join("**/*"), File::FNM_DOTMATCH).each do |p|
          next unless File.file?(p)

          rel = Pathname.new(p).relative_path_from(@root)
          next if rel.to_s.split(File::SEPARATOR).size > @max_depth
          next if rel.to_s.split(File::SEPARATOR).any? { |d| SKIP_DIRS.include?(d) }

          next unless exts.include?(File.extname(p))

          files << Pathname.new(p)
        end
        files
      end

      def scan_file(path)
        text = File.read(path, encoding: "UTF-8")
        lines = text.lines
        owner = @path_resolver.owning_service(path, @root)
        return unless owner

        from_id = "service:#{owner}"

        lines.each_with_index do |line, idx|
          line_no = idx + 1

          PUBLISH.each do |re|
            line.scan(re) do |m|
              topic = m.is_a?(Array) ? m.first : m
              next if topic.nil? || topic.length > 200

              ensure_stream_node(topic)
              @graph.add_edge(
                from: from_id,
                to: "stream:#{sanitize_id(topic)}",
                type: :publishes,
                confidence: :medium,
                source_file: path.to_s,
                line_number: line_no,
                metadata: { topic: topic }
              )
            end
          end

          CONSUME.each do |re|
            line.scan(re) do |m|
              topic = m.is_a?(Array) ? m.first : m
              next if topic.nil? || topic.length > 200

              ensure_stream_node(topic)
              @graph.add_edge(
                from: "stream:#{sanitize_id(topic)}",
                to: from_id,
                type: :consumes,
                confidence: :medium,
                source_file: path.to_s,
                line_number: line_no,
                metadata: { topic: topic }
              )
            end
          end
        end
      rescue StandardError => e
        warn "vizult: stream scan #{path}: #{e.message}" if ENV["VIZULT_DEBUG"]
      end

      def ensure_stream_node(topic)
        id = "stream:#{sanitize_id(topic)}"
        return if @graph.node?(id)

        @graph.add_node(id: id, type: :stream, label: topic, metadata: {})
      end

      def sanitize_id(topic)
        topic.gsub(/[^\w\-:.]/, "_")[0, 120]
      end
    end
  end
end

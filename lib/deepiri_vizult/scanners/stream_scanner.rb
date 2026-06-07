# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  module Scanners
    class StreamScanner
      # Each pattern captures the first call argument as either a string literal
      # (named group `lit`) or a constant reference (named group `ref`, e.g.
      # `StreamTopics.PLATFORM_EVENTS`). `\s*` after the opening paren lets the
      # topic sit on a following line, so multi-line calls are matched too.
      PUBLISH = [
        /\.publish\s*\(\s*(?:['"](?<lit>[^'"]+)['"]|(?<ref>[A-Za-z_][\w.]*))/,
        /\bxadd\s*\(\s*(?:['"](?<lit>[^'"]+)['"]|(?<ref>[A-Za-z_][\w.]*))/i,
        /\bproducer\.send\s*\(\s*(?:['"](?<lit>[^'"]+)['"]|(?<ref>[A-Za-z_][\w.]*))/,
        /\btopics?\s*[=:]\s*['"](?<lit>[^'"]+)['"]/
      ].freeze

      CONSUME = [
        /\.subscribe\s*\(\s*(?:['"](?<lit>[^'"]+)['"]|(?<ref>[A-Za-z_][\w.]*))/,
        /\bconsumer\.subscribe\s*\(\s*\{?\s*topics?\s*:\s*['"](?<lit>[^'"]+)['"]/,
        /\bxread\s*\(\s*\{?\s*['"](?<lit>[^'"]+)['"]/i,
        /from\s+['"](?<lit>[^'"]+)['"]\s*#\s*kafka/i
      ].freeze

      # Redis stream IDs / wildcards that are sometimes captured by the
      # publish/consume regexes but are never real topic names.
      REDIS_SPECIAL_IDS = %w[> $ * + - = ~].freeze

      def initialize(root:, graph:, registry:, max_depth: 12)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
        @path_resolver = PathResolver.new(registry)
        @topic_consts = TopicConstants.new
      end

      def scan
        fs = files
        fs.each { |f| @topic_consts.add_file(f) }
        fs.each { |f| scan_file(f) }
      end

      private

      def files
        exts = %w[.ts .tsx .js .jsx .py .go .rb]
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
        owner = @path_resolver.owning_service(path, @root)
        return unless owner

        from_id = "service:#{owner}"

        match_calls(text, PUBLISH) do |topic, meta, line_no|
          stream_id = "stream:#{sanitize_id(topic)}"
          ensure_stream_node(topic)
          next if edge?(from_id, stream_id, :publishes)

          @graph.add_edge(
            from: from_id,
            to: stream_id,
            type: :publishes,
            confidence: :medium,
            source_file: path.to_s,
            line_number: line_no,
            metadata: meta
          )
        end

        match_calls(text, CONSUME) do |topic, meta, line_no|
          stream_id = "stream:#{sanitize_id(topic)}"
          ensure_stream_node(topic)
          next if edge?(stream_id, from_id, :consumes)

          @graph.add_edge(
            from: stream_id,
            to: from_id,
            type: :consumes,
            confidence: :medium,
            source_file: path.to_s,
            line_number: line_no,
            metadata: meta
          )
        end
      rescue StandardError => e
        warn "vizult: stream scan #{path}: #{e.message}" if ENV["VIZULT_DEBUG"]
      end

      def match_calls(text, patterns)
        patterns.each do |re|
          text.scan(re) do
            m = Regexp.last_match
            cap = resolve_capture(m)
            next unless cap

            topic, meta = cap
            yield topic, meta, line_of(text, m.begin(0))
          end
        end
      end

      # Turns a match into [topic_value, metadata] or nil. Literal topics are
      # taken as-is; constant references are resolved against the topic-constant
      # index and dropped (never named after the symbol) when unresolved.
      def resolve_capture(match)
        names = match.names
        lit = names.include?("lit") ? match[:lit] : nil
        ref = names.include?("ref") ? match[:ref] : nil

        if lit && !lit.empty?
          return nil unless plausible_topic?(lit)

          [lit, { topic: lit }]
        elsif ref
          value = @topic_consts.resolve(ref)
          return nil unless value && plausible_topic?(value)

          [value, { topic: value, topic_const: ref }]
        end
      end

      # Filters out captures that are syntactically valid quoted strings but are
      # clearly not message topics: Redis special IDs (`>`, `$`, `*`), wildcards,
      # punctuation-only tokens (`.`), single characters, and over-long blobs.
      def plausible_topic?(topic)
        return false if topic.nil?

        t = topic.strip
        return false if t.length < 2 || t.length > 200
        return false if REDIS_SPECIAL_IDS.include?(t)
        return false unless t.match?(/[A-Za-z0-9]/)

        true
      end

      def line_of(text, offset)
        text[0...offset].count("\n") + 1
      end

      def edge?(from_id, to_id, type)
        @graph.edges.any? { |e| e[:from] == from_id && e[:to] == to_id && e[:type] == type }
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

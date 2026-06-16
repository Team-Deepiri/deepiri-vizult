# frozen_string_literal: true

require 'set'

module DeepiriVizult
  module Scanners
    # Builds a lookup of topic-name constants so stream calls that pass a symbol
    # (e.g. `StreamTopics.PLATFORM_EVENTS`) instead of a string literal can be
    # resolved to the real topic value ("platform-events").
    #
    # Supported definition shapes:
    #   Python   class StreamTopics(str, Enum):
    #                PLATFORM_EVENTS = "platform-events"
    #   TS/JS     enum StreamTopics { PLATFORM_EVENTS = 'platform-events' }
    #             const StreamTopics = { PLATFORM_EVENTS: 'platform-events' }
    #
    # Resolution prefers the qualified form (`Type.MEMBER`); a bare member name
    # is only used when exactly one definition with that name exists, so two
    # unrelated enums sharing a member name never resolve ambiguously.
    class TopicConstants
      PY_CLASS  = /^\s*class\s+([A-Za-z_]\w*)/
      PY_CONST  = /^(\s*)([A-Z][A-Z0-9_]*)\s*=\s*['"]([^'"]+)['"]/
      TS_OPEN   = /(?:enum|const)\s+([A-Za-z_]\w*)/
      TS_MEMBER = /([A-Za-z_]\w*)\s*[:=]\s*['"]([^'"]+)['"]/
      TS_EXTS   = %w[.ts .tsx .js .jsx .mjs .cjs].freeze

      def initialize
        @qualified = {} # "StreamTopics.PLATFORM_EVENTS" => "platform-events"
        @bare = Hash.new { |h, k| h[k] = Set.new } # "PLATFORM_EVENTS" => Set[values]
      end

      def add_file(path)
        text = File.read(path, encoding: 'UTF-8')
        case File.extname(path.to_s)
        when '.py' then scan_python(text)
        when *TS_EXTS then scan_ts(text)
        end
      rescue StandardError
        nil
      end

      # @param ref [String] e.g. "StreamTopics.PLATFORM_EVENTS" or "PLATFORM_EVENTS"
      # @return [String, nil] resolved topic value, or nil if unknown/ambiguous
      #
      # A dotted reference (`Type.MEMBER`) must match a known qualifier exactly;
      # it deliberately does NOT fall back to the bare member name, so something
      # like `spec.stream` can't resolve through an unrelated `stream` constant.
      # A bare reference resolves only when exactly one definition exists.
      def resolve(ref)
        return @qualified[ref] if @qualified.key?(ref)
        return nil if ref.include?('.')

        values = @bare[ref]
        values.size == 1 ? values.first : nil
      end

      private

      def add(qualifier, name, value)
        @qualified["#{qualifier}.#{name}"] = value if qualifier
        @bare[name] << value
      end

      def scan_python(text)
        current_class = nil
        text.each_line do |line|
          if (m = line.match(PY_CLASS))
            current_class = m[1]
            next
          end
          # A non-indented statement that is not a constant ends the class body.
          if (m = line.match(PY_CONST))
            add(current_class, m[2], m[3])
          elsif line.match?(/^\S/) && !line.match?(PY_CLASS)
            current_class = nil
          end
        end
      end

      def scan_ts(text)
        qualifier = nil
        depth = 0
        text.each_line do |line|
          if qualifier.nil? && (m = line.match(TS_OPEN)) && line.include?('{')
            qualifier = m[1]
            depth = 0
          end

          next unless qualifier
          line.scan(TS_MEMBER) { |name, value| add(qualifier, name, value) }
          depth += line.count('{') - line.count('}')
          qualifier = nil if depth <= 0
        end
      end
    end
  end
end

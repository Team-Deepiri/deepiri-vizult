# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  module Scanners
    class SourceScanner
      EXTENSIONS = %w[.ts .tsx .js .jsx .mjs .cjs .py .go .rb].freeze

      # URL-like strings in code
      URL_IN_STRING = %r{["'`](https?://[^"'`\s]+)["'`]}.freeze
      # process.env.FOO || 'http://...'
      ENV_DEFAULT = /process\.env\.(\w+)\s*\|\|\s*['"]([^'"]+)['"]/.freeze
      ENV_GET = /process\.env\[['"](\w+)['"]\]/.freeze
      OS_GETENV = /os\.getenv\s*\(\s*["'](\w+)["']\s*(?:,\s*["']([^"']*)["'])?\s*\)/.freeze
      TARGET_PROXY = /target:\s*['"](https?:\/\/[^'"]+)['"]/.freeze
      PROXY_PASS = /proxy_pass\s+(https?:\/\/[^;\s]+|[^;\s]+);/.freeze

      def initialize(root:, graph:, registry:, max_depth: 12)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
        @url_resolver = UrlResolver.new(registry)
        @path_resolver = PathResolver.new(registry)
      end

      def scan
        source_files.each { |f| scan_file(f) }
      end

      private

      def source_files
        ProjectFiles.list(@root).select do |p|
          EXTENSIONS.include?(p.extname) && within_depth?(p)
        end
      end

      def within_depth?(path)
        path.relative_path_from(@root).to_s.split(File::SEPARATOR).size <= @max_depth
      rescue ArgumentError
        true
      end

      def scan_file(path)
        text = File.read(path, encoding: "UTF-8")
        lines = text.lines
        owner = @path_resolver.owning_service(path, @root)
        owner_id = owner ? "service:#{owner}" : nil

        lines.each_with_index do |line, idx|
          line_no = idx + 1

          line.scan(URL_IN_STRING) do |m|
            url = m[0]
            target = @url_resolver.resolve_service(url)
            add_http_edge(owner_id, target, path, line_no, :high) if target
          end

          if (m = line.match(ENV_DEFAULT))
            var, default_url = m.captures
            target = EnvResolver.new(@registry).resolve(var, default_url)
            add_http_edge(owner_id, target, path, line_no, :medium) if target
          end

          if (m = line.match(OS_GETENV))
            var = m[1]
            default = m[2]
            target = EnvResolver.new(@registry).resolve(var, default)
            add_http_edge(owner_id, target, path, line_no, :medium) if target
          end

          if (m = line.match(TARGET_PROXY))
            url = m[1]
            target = @url_resolver.resolve_service(url)
            add_http_edge(owner_id, target, path, line_no, :high, :http_proxy) if target
          end

          if (m = line.match(PROXY_PASS))
            url = m[1]
            next if url.start_with?("$")

            target = @url_resolver.resolve_service(url)
            add_http_edge(owner_id, target, path, line_no, :high, :http_proxy) if target
          end
        end
      rescue ArgumentError, Encoding::CompatibilityError, StandardError => e
        warn "vizult: skip #{path}: #{e.message}" if ENV["VIZULT_DEBUG"]
      end

      def add_http_edge(from_id, target_service_name, path, line_no, confidence, type = :http_call)
        to_id = "service:#{target_service_name}"
        return unless @graph.node?(to_id) || @registry.services.key?(target_service_name)

        @graph.add_node(id: to_id, type: :service, label: target_service_name, metadata: {}) unless @graph.node?(to_id)

        from =
          if from_id && @graph.node?(from_id)
            from_id
          else
            rid = "repo:#{@root.basename}"
            @graph.add_node(id: rid, type: :repo, label: @root.basename.to_s, metadata: {}) unless @graph.node?(rid)
            rid
          end

        @graph.add_edge(
          from: from,
          to: to_id,
          type: type,
          confidence: confidence,
          source_file: path.to_s,
          line_number: line_no
        )
      end
    end
  end
end

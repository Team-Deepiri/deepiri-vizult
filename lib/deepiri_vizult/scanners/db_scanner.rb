# frozen_string_literal: true

require 'pathname'

module DeepiriVizult
  module Scanners
    class DbScanner
      DB_ENV = /(?:DATABASE_URL|MONGO_URI|REDIS_URL|MILVUS_|POSTGRES_|MYSQL_|ELASTICSEARCH_)/i.freeze

      def initialize(root:, graph:, registry:, max_depth: 12)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
        @path_resolver = PathResolver.new(registry)
        @url_resolver = UrlResolver.new(registry)
      end

      def scan
        scan_env_in_files
        scan_prisma
      end

      private

      ENV_FILE = /\A(?:\.env\.example|\.env\.sample|docker-compose.*\.ya?ml)\z/.freeze

      def scan_env_in_files
        ProjectFiles.list(@root).each do |p|
          scan_text_file(p) if p.basename.to_s.match?(ENV_FILE)
        end
      end

      def scan_text_file(path)
        text = File.read(path, encoding: 'UTF-8')
        text.each_line.with_index do |line, idx|
          next unless line.match?(DB_ENV)
          next unless line.match?(%r{@|://})

          if (m = line.match(%r{(\w+)=['"]?([^'"\s]+)}))
            _k, val = m.captures
            host = extract_host(val)
            next unless host

            ensure_db_node(host, val)
            @graph.add_edge(
              from: "repo:#{@root.basename}",
              to: "db:#{sanitize(host)}",
              type: :db_access,
              confidence: :low,
              source_file: path.to_s,
              line_number: idx + 1
            )
          end
        end
      rescue StandardError
        nil
      end

      def extract_host(connection_string)
        host =
          if connection_string =~ %r{//([^/:]+)[:/]}
            Regexp.last_match(1)
          else
            connection_string
          end
        return nil unless plausible_host?(host)

        host
      end

      # File-backed / relative connection strings (e.g. `sqlite:///./app.db`)
      # yield hosts like `.` or `..` that are not real database hosts.
      def plausible_host?(host)
        return false if host.nil?

        h = host.strip
        return false if h.empty?
        return false if h == '.' || h == '..'
        return false unless h.match?(/[A-Za-z0-9]/)

        true
      end

      def scan_prisma
        ProjectFiles.list(@root).each do |path|
          next unless path.basename.to_s == 'schema.prisma'

          text = File.read(path, encoding: 'UTF-8')
          next unless (m = text.match(/provider\s*=\s*"(\w+)"/))

          provider = m[1]
          url_line = text[/url\s*=\s*env\("([^"]+)"\)/, 1]
          owner = @path_resolver.owning_service(path, @root)
          db_id = "db:prisma-#{provider}"
          @graph.add_node(id: db_id, type: :database, label: "#{provider} (prisma)", metadata: { provider: provider }) unless @graph.node?(db_id)

          next unless owner

          @graph.add_edge(
            from: "service:#{owner}",
            to: db_id,
            type: :db_access,
            confidence: :medium,
            source_file: path.to_s,
            metadata: { env_var: url_line }
          )
        end
      end

      def ensure_db_node(host, raw)
        id = "db:#{sanitize(host)}"
        return if @graph.node?(id)

        @graph.add_node(id: id, type: :database, label: host, metadata: { sample: raw[0, 80] })
      end

      def sanitize(s)
        s.to_s.gsub(/[^\w-]/, '_')[0, 80]
      end
    end
  end
end

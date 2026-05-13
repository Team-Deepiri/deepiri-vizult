# frozen_string_literal: true

require "yaml"
require "pathname"

module DeepiriVizult
  module Scanners
    class ComposeScanner
      ENV_URL_KEYS = /_URL$|_HOST$|_URI$|_SERVICE$/i.freeze

      def initialize(root:, graph:, registry:, max_depth: 10)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
      end

      def scan
        compose_files.each do |cf|
          process_file(cf)
        end
      end

      private

      def compose_files
        patterns = ["docker-compose*.yml", "docker-compose*.yaml", "compose.yml", "compose.yaml"]
        files = []
        Dir.glob(@root.join("**/*"), File::FNM_DOTMATCH).each do |p|
          next unless File.file?(p)

          rel = Pathname.new(p).relative_path_from(@root)
          depth = rel.to_s.split(File::SEPARATOR).size
          next if depth > @max_depth

          base = File.basename(p)
          next unless patterns.any? { |g| File.fnmatch(g, base, File::FNM_CASEFOLD) }

          files << Pathname.new(p)
        end
        files.uniq
      end

      def process_file(path)
        text = File.read(path, encoding: "UTF-8")
        data = YAML.safe_load(text, permitted_classes: [Symbol, Time], aliases: true) || {}
        services = data["services"] || {}
        compose_rel = path.relative_path_from(@root).to_s

        services.each do |svc_name, svc_def|
          next if svc_def.nil? || !svc_def.is_a?(Hash)

          register_service(svc_name, svc_def, path, compose_rel)
        end

        services.each do |svc_name, svc_def|
          next if svc_def.nil? || !svc_def.is_a?(Hash)

          deps = svc_def["depends_on"]
          case deps
          when Array
            deps.each do |dep|
              dep_name = dep.is_a?(Hash) ? dep.keys.first : dep
              add_depends_edge(svc_name.to_s, dep_name.to_s, path.to_s)
            end
          when Hash
            deps.each_key do |dep_name|
              add_depends_edge(svc_name.to_s, dep_name.to_s, path.to_s)
            end
          end
        end
      rescue Psych::SyntaxError, StandardError => e
        warn "vizult: skip compose #{path}: #{e.message}" if ENV["VIZULT_DEBUG"]
      end

      def register_service(name, svc_def, compose_path, compose_rel)
        hostnames = [name]
        ports = extract_ports(svc_def["ports"])
        source_dirs = extract_build_contexts(svc_def, compose_path.dirname)
        env_refs = extract_env(svc_def)

        @registry.register(
          name,
          hostnames: hostnames,
          ports: ports,
          source_dirs: source_dirs,
          compose_file: compose_rel,
          env_refs: env_refs
        )

        sid = "service:#{name}"
        unless @graph.node?(sid)
          @graph.add_node(
            id: sid,
            type: :service,
            label: name,
            metadata: { compose: compose_rel }
          )
        end

        # repo contains service (best effort: root repo)
        root_repo = "repo:#{@root.basename}"
        @graph.add_edge(from: root_repo, to: sid, type: :contains, confidence: :high) if @graph.node?(root_repo)
      end

      def extract_ports(ports_field)
        out = { host: nil, container: nil }
        return out if ports_field.nil?

        arr = ports_field.is_a?(Array) ? ports_field : [ports_field]
        first = arr.first
        case first
        when String
          if first.include?(":")
            parts = first.split(":")
            out[:host] = parts[0].to_i if parts[0].match?(/^\d+$/)
            out[:container] = parts[-1].to_i if parts[-1].match?(/^\d+$/)
          elsif first.match?(/^\d+$/)
            p = first.to_i
            out[:host] = p
            out[:container] = p
          end
        when Hash
          out[:host] = first["published"]&.to_i
          out[:container] = first["target"]&.to_i
        end
        out
      end

      def extract_build_contexts(svc_def, compose_dir)
        dirs = []
        b = svc_def["build"]
        return dirs unless b

        ctx = b.is_a?(Hash) ? b["context"] : b
        if ctx
          d = compose_dir.join(ctx).expand_path
          dirs << d if d.directory?
        end

        # Many services share a broad build context (e.g. `./platform-services`) and disambiguate
        # via `dockerfile: backend/<svc>/Dockerfile`. The dockerfile's directory is the actual
        # per-service location and is what PathResolver needs to attribute source files (prisma
        # schemas, .ts files, etc.) to the right owner.
        if b.is_a?(Hash) && (df = b["dockerfile"])
          base = ctx ? compose_dir.join(ctx) : compose_dir
          df_dir = base.join(File.dirname(df.to_s)).expand_path
          dirs << df_dir if df_dir.directory? && !dirs.include?(df_dir)
        end

        dirs
      end

      def extract_env(svc_def)
        refs = {}
        env = svc_def["environment"]
        case env
        when Hash
          env.each { |k, v| store_env_ref(refs, k, v) }
        when Array
          env.each do |line|
            k, v = line.to_s.split("=", 2)
            store_env_ref(refs, k, v) if k
          end
        end
        refs
      end

      def store_env_ref(refs, key, value)
        return if value.nil?

        k = key.to_s
        v = value.to_s
        refs[k] = v if k.match?(ENV_URL_KEYS) || v.match?(%r{^https?://})
      end

      def add_depends_edge(from_svc, to_svc, source_file)
        @graph.add_edge(
          from: "service:#{from_svc}",
          to: "service:#{to_svc}",
          type: :depends_on,
          confidence: :high,
          source_file: source_file
        )
      end
    end
  end
end

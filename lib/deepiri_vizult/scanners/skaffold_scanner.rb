# frozen_string_literal: true

require 'yaml'
require 'pathname'

module DeepiriVizult
  module Scanners
    # Parses skaffold.yaml / skaffold.yml: build artifacts (image + context). Each artifact becomes a
    # service node via register_from_artifact; the skaffold manifest file itself is not represented
    # as a node (it carried no graph-level meaning and just polluted the canvas with stray endpoints).
    class SkaffoldScanner
      def initialize(root:, graph:, registry:, max_depth: 14)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
      end

      def scan
        skaffold_files.each do |path|
          next unless path.file?
          next if path.to_s.include?('node_modules')

          rel = path.relative_path_from(@root)
          next if rel.to_s.split(File::SEPARATOR).size > @max_depth

          process_file(path, rel)
        end
      end

      def skaffold_files
        %w[skaffold.yaml skaffold.yml].flat_map do |name|
          Dir.glob(@root.join("**/#{name}").to_s, File::FNM_DOTMATCH).map { |p| Pathname.new(p) }
        end.uniq
      end

      private

      def process_file(path, _rel)
        text = File.read(path, encoding: 'UTF-8')
        data = YAML.safe_load(text, permitted_classes: [Symbol, Time], aliases: true) || {}
        return unless data.is_a?(Hash)

        artifacts = Array(data.dig('build', 'artifacts'))
                    .map { |a| artifact_entry(a, path.dirname) }
                    .compact

        artifacts.each do |art|
          next unless art[:context_path]

          register_from_artifact(art)
        end
      rescue Psych::SyntaxError, StandardError => e
        warn "vizult: skip skaffold #{path}: #{e.message}" if ENV['VIZULT_DEBUG']
      end

      def artifact_entry(artifact, skaffold_dir)
        return nil unless artifact.is_a?(Hash)

        image = artifact['image']&.to_s
        ctx = artifact['context']&.to_s
        if ctx.nil? && artifact['docker'].is_a?(Hash)
          df = artifact['docker']['dockerfile']&.to_s
          ctx = File.dirname(df) if df && !df.empty?
        end
        return nil unless image && ctx && !ctx.empty?

        abs_ctx = skaffold_dir.join(ctx).expand_path
        {
          image: image,
          context: ctx,
          context_path: abs_ctx.directory? ? abs_ctx : nil
        }
      end

      def register_from_artifact(art)
        image = art[:image]
        dir = art[:context_path]
        return unless dir&.directory?

        # Service key: last segment of image (e.g. registry/deepiri-api-gateway -> deepiri-api-gateway)
        key = image.split('/').last.split(':').first
        return if key.nil? || key.empty?

        key = key.gsub(/[^\w.-]/, '_')
        @registry.register(
          key,
          hostnames: [key.tr('_', '-')],
          source_dirs: [dir],
          compose_file: nil,
          env_refs: {}
        )

        svc = "service:#{key}"
        return if @graph.node?(svc)

        @graph.add_node(id: svc, type: :service, label: key, metadata: { source: 'skaffold', image: image })
      end
    end
  end
end

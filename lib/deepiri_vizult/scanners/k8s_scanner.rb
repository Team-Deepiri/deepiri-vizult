# frozen_string_literal: true

require 'yaml'
require 'pathname'

module DeepiriVizult
  module Scanners
    class K8sScanner
      KINDS = %w[Deployment Service StatefulSet].freeze

      def initialize(root:, graph:, registry:, max_depth: 12)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @registry = registry
        @max_depth = max_depth
      end

      def scan
        yaml_files.each { |f| process_file(f) }
      end

      private

      def yaml_files
        files = []
        Dir.glob(@root.join('**/*.{yml,yaml}'), File::FNM_DOTMATCH).each do |p|
          next unless File.file?(p)

          rel = Pathname.new(p).relative_path_from(@root)
          next if rel.to_s.split(File::SEPARATOR).size > @max_depth

          # skip node_modules, vendor, etc.
          next if rel.to_s.include?('node_modules') || rel.to_s.include?('vendor/bundle')

          files << Pathname.new(p)
        end
        files
      end

      def process_file(path)
        text = File.read(path, encoding: 'UTF-8')
        # multi-doc YAML: take first doc with kind
        text.split(/^---\s*$/).each do |doc|
          next if doc.strip.empty?

          data = begin
            YAML.safe_load(doc, permitted_classes: [Symbol, Time], aliases: true)
          rescue StandardError
            nil
          end
          next unless data.is_a?(Hash)

          kind = data['kind']
          next unless KINDS.include?(kind)

          process_manifest(data, path, kind)
        end
      rescue StandardError => e
        warn "vizult: skip k8s #{path}: #{e.message}" if ENV['VIZULT_DEBUG']
      end

      def process_manifest(data, path, kind)
        meta = data['metadata'] || {}
        name = meta['name']
        return unless name

        case kind
        when 'Service'
          register_service_ports(name, data['spec'])
        when 'Deployment', 'StatefulSet'
          register_containers(name, data.dig('spec', 'template', 'spec', 'containers'), path)
        end
      end

      def register_service_ports(name, spec)
        return unless spec

        ports = spec['ports']
        return unless ports.is_a?(Array) && ports.first

        p = ports.first
        container_port = p['port']&.to_i
        @registry.register(
          name,
          hostnames: [name, "#{name}.default.svc.cluster.local"],
          ports: { host: nil, container: container_port },
          compose_file: nil,
          env_refs: {}
        )
        sid = "service:#{name}"
        return if @graph.node?(sid)

        @graph.add_node(id: sid, type: :service, label: name, metadata: { source: 'k8s' })
      end

      def register_containers(deployment_name, containers, _path)
        return unless containers.is_a?(Array)

        containers.each do |c|
          env = c['env']
          next unless env.is_a?(Array)

          refs = {}
          env.each do |e|
            n = e['name']
            v = e['value'] || e.dig('valueFrom', 'configMapKeyRef', 'key')
            refs[n] = v if n && v.is_a?(String) && (n.match?(/_URL$|_HOST$|_URI$/i) || v.match?(%r{^https?://}))
          end
          next if refs.empty?

          @registry.merge_env_refs(deployment_name, refs)
        end
      end
    end
  end
end

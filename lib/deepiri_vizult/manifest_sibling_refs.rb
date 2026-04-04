# frozen_string_literal: true

require "json"
require "pathname"

module DeepiriVizult
  # Detects relative path dependencies in manifests that point at co-located repo directory names.
  class ManifestSiblingRefs
    FILE_DEP = %r{file:\s*(\.\./|\./)([^"'\s]+)}i
    LINK_DEP = %r{link:\s*(\.\./|\./)([^"'\s]+)}i
    GO_REPLACE = /replace\s+\S+\s+=>\s*(\.\.\/|\.\/)([^\s]+)/

    class << self
      def apply(graph, root)
        root = Pathname.new(root).expand_path
        basenames = collect_sibling_basenames(root)
        basenames << root.basename.to_s

        scan_repo(graph, root, basenames)
        SiblingRoots.list(root).each { |p| scan_repo(graph, p, basenames) }
      end

      def collect_sibling_basenames(root)
        SiblingRoots.list(root).map { |p| p.basename.to_s }.uniq
      end

      def scan_repo(graph, repo_path, known_basenames)
        rid = "repo:#{repo_path.basename}"
        return unless graph.node?(rid)

        pj = repo_path.join("package.json")
        scan_package_json(graph, rid, pj, known_basenames) if pj.file?

        gm = repo_path.join("go.mod")
        scan_go_mod(graph, rid, gm, known_basenames) if gm.file?
      end

      def scan_package_json(graph, from_repo_id, path, known_basenames)
        data = JSON.parse(File.read(path, encoding: "UTF-8"))
        %w[dependencies devDependencies peerDependencies].each do |key|
          (data[key] || {}).each do |_pkg, ver|
            next unless ver.is_a?(String)

            targets = relative_targets(ver)
            targets.each do |base|
              next unless known_basenames.include?(base)

              tid = "repo:#{base}"
              next unless graph.node?(tid)
              next if edge_present?(graph, from_repo_id, tid, :manifest_ref)

              graph.add_edge(
                from: from_repo_id,
                to: tid,
                type: :manifest_ref,
                confidence: :medium,
                source_file: path.to_s,
                line_number: nil,
                metadata: { manifest: "package.json" }
              )
            end
          end
        end
      rescue JSON::ParserError
        nil
      end

      def scan_go_mod(graph, from_repo_id, path, known_basenames)
        File.foreach(path, encoding: "UTF-8") do |line|
          next unless (m = line.match(GO_REPLACE))

          base = m[2].to_s.split(%r{/}).first
          next if base.nil? || base.empty?
          next unless known_basenames.include?(base)

          tid = "repo:#{base}"
          next unless graph.node?(tid)
          next if edge_present?(graph, from_repo_id, tid, :manifest_ref)

          graph.add_edge(
            from: from_repo_id,
            to: tid,
            type: :manifest_ref,
            confidence: :medium,
            source_file: path.to_s,
            line_number: nil,
            metadata: { manifest: "go.mod" }
          )
        end
      end

      def relative_targets(spec)
        out = []
        spec.to_s.scan(FILE_DEP) { out << basename_from_rel(::Regexp.last_match(2)) }
        spec.to_s.scan(LINK_DEP) { out << basename_from_rel(::Regexp.last_match(2)) }
        out.compact.uniq
      end

      def basename_from_rel(fragment)
        frag = fragment.to_s.sub(%r{\A\./}, "").sub(%r{/\z}, "")
        return nil if frag.empty?

        parts = frag.split(%r{/})
        parts.first
      end

      def edge_present?(graph, from_id, to_id, type)
        graph.edges.any? { |e| e[:from] == from_id && e[:to] == to_id && e[:type] == type }
      end
    end
  end
end

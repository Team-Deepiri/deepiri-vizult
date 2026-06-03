# frozen_string_literal: true

require 'pathname'

module DeepiriVizult
  # Infers weak structural links between co-located git clones when no evidence edge connects them.
  class CrossRepoLinker
    class << self
      def path_exists?(graph, from_id, to_id)
        return true if from_id == to_id

        adj = Hash.new { |h, k| h[k] = [] }
        graph.edges.each do |e|
          adj[e[:from]] << e[:to]
          adj[e[:to]] << e[:from]
        end

        visited = { from_id => true }
        queue = [from_id]
        until queue.empty?
          u = queue.shift
          return true if u == to_id

          adj[u].each do |v|
            next if visited[v]

            visited[v] = true
            queue << v
          end
        end
        false
      end

      # Star edges from scan root to each sibling repo when the graph has no connecting path.
      def apply_adjacent_clones!(graph, root)
        root = Pathname.new(root).expand_path
        root_id = "repo:#{root.basename}"
        return unless graph.node?(root_id)

        SiblingRoots.list(root).each do |sib_path|
          sid = "repo:#{sib_path.basename}"
          next unless graph.node?(sid)
          next if path_exists?(graph, root_id, sid)

          graph.add_edge(
            from: root_id,
            to: sid,
            type: :adjacent_clone,
            confidence: :low,
            source_file: nil,
            line_number: nil,
            metadata: { inference: true, reason: 'same_parent_directory_no_wire_detected' }
          )
        end
      end

      # Low-confidence edges between sibling pairs (excluding root) that share git remote org metadata.
      def apply_same_org!(graph, root)
        root = Pathname.new(root).expand_path
        siblings = SiblingRoots.list(root)
        ids = siblings.map { |p| "repo:#{p.basename}" }.select { |id| graph.node?(id) }

        ids.combination(2).each do |a, b|
          org_a = graph.nodes[a].dig(:metadata, :org)
          org_b = graph.nodes[b].dig(:metadata, :org)
          next unless org_a && org_b && org_a == org_b
          next if path_exists?(graph, a, b)

          graph.add_edge(
            from: a,
            to: b,
            type: :same_org,
            confidence: :low,
            source_file: nil,
            line_number: nil,
            metadata: { inference: true, reason: 'shared_git_remote_org' }
          )
        end
      end

      def apply!(graph, root, siblings:, infer_org_links:)
        return unless siblings

        apply_adjacent_clones!(graph, root)
        apply_same_org!(graph, root) if infer_org_links
      end
    end
  end
end

# frozen_string_literal: true

module DeepiriVizult
  # Typed graph: nodes (repo, service, stream, database, endpoint) and edges with evidence.
  class Graph
    attr_reader :nodes, :edges # nodes: id => hash

    def initialize
      @nodes = {} # id => { id:, type:, label:, metadata: }
      @edges = [] # { id:, from:, to:, type:, confidence:, source_file:, line_number:, metadata: }
      @edge_seq = 0
    end

    def add_node(id:, type:, label:, metadata: {})
      @nodes[id] = { id: id, type: type.to_sym, label: label.to_s, metadata: metadata }
    end

    def node?(id)
      @nodes.key?(id)
    end

    def add_edge(from:, to:, type:, confidence: :medium, source_file: nil, line_number: nil, metadata: {})
      @edge_seq += 1
      eid = "e#{@edge_seq}"
      @edges << {
        id: eid,
        from: from.to_s,
        to: to.to_s,
        type: type.to_sym,
        confidence: confidence.to_sym,
        source_file: source_file,
        line_number: line_number,
        metadata: metadata
      }
      eid
    end

    def edges_for(node_id)
      nid = node_id.to_s
      @edges.select { |e| e[:from] == nid || e[:to] == nid }
    end

    def to_h
      {
        nodes: @nodes.values,
        edges: @edges
      }
    end

    # Merges another graph with a string prefix on every node id (and matching edge endpoints).
    # Skips nodes that already exist under the prefixed id. Only adds edges when both ends exist.
    def merge_prefixed!(other, prefix:)
      other.nodes.each do |old_id, n|
        new_id = "#{prefix}#{old_id}"
        next if @nodes.key?(new_id)

        meta = (n[:metadata] || {}).dup
        meta[:merged_from_id] = old_id
        add_node(id: new_id, type: n[:type], label: n[:label], metadata: meta)
      end

      other.edges.each do |e|
        nf = "#{prefix}#{e[:from]}"
        nt = "#{prefix}#{e[:to]}"
        next unless @nodes[nf] && @nodes[nt]

        add_edge(
          from: nf,
          to: nt,
          type: e[:type],
          confidence: e[:confidence] || :medium,
          source_file: e[:source_file],
          line_number: e[:line_number],
          metadata: (e[:metadata] || {}).dup
        )
      end
      self
    end
  end
end

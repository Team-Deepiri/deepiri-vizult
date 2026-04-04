# frozen_string_literal: true

require "json"
require "time"

module DeepiriVizult
  module Renderers
    class JsonRenderer
      def initialize(graph)
        @graph = graph
      end

      def render
        JSON.pretty_generate(
          {
            generated_at: Time.now.utc.iso8601,
            meta: { node_count: @graph.nodes.size, edge_count: @graph.edges.size },
            graph: @graph.to_h
          }
        )
      end

      def write(path)
        File.write(path, render, encoding: "UTF-8")
      end
    end
  end
end

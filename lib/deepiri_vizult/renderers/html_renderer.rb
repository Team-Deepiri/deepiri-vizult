# frozen_string_literal: true

require "erb"
require "json"

require_relative "../version"

module DeepiriVizult
  module Renderers
    class HtmlRenderer
      CYTOSCAPE_CDN = "https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.28.1/cytoscape.min.js"

      def initialize(graph)
        @graph = graph
      end

      def render
        template_path = File.join(__dir__, "..", "templates", "viewer.html.erb")
        tpl = File.read(template_path, encoding: "UTF-8")
        erb = ERB.new(tpl)
        elements_json = cytoscape_elements_json
        graph_json = JSON.generate(@graph.to_h)
        erb.result_with_hash(
          cytoscape_cdn: CYTOSCAPE_CDN,
          graph_json: graph_json,
          elements_json: elements_json,
          node_count: @graph.nodes.size,
          edge_count: @graph.edges.size,
          vizult_version: DeepiriVizult::VERSION
        )
      end

      def write(path)
        File.write(path, render, encoding: "UTF-8")
      end

      private

      def cytoscape_elements_json
        node_ids = @graph.nodes.keys.to_h { |id| [id, true] }
        elements = []
        @graph.nodes.each do |id, n|
          elements << {
            data: {
              id: id,
              label: n[:label],
              type: n[:type].to_s
            }
          }
        end
        @graph.edges.each do |e|
          next unless node_ids[e[:from]] && node_ids[e[:to]]

          elements << {
            data: {
              id: e[:id],
              source: e[:from],
              target: e[:to],
              label: e[:type].to_s,
              confidence: e[:confidence].to_s,
              sourceFile: e[:source_file],
              line: e[:line_number],
              inferred: e.dig(:metadata, :inference) ? true : false,
              scanOverlay: e.dig(:metadata, :merged_scan) ? true : false
            }
          }
        end
        JSON.generate(elements)
      end
    end
  end
end

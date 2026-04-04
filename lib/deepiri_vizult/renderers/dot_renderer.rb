# frozen_string_literal: true

module DeepiriVizult
  module Renderers
    # Graphviz directed graph (UTF-8). Render with: dot -Tpng system.dot -o system.png
    class DotRenderer
      def initialize(graph)
        @graph = graph
      end

      def render_system
        build_dot(@graph.edges)
      end

      REPO_VIEW_TYPES = %i[
        contains imports adjacent_clone same_org manifest_ref scan_overlay
      ].freeze

      def render_repos
        build_dot(@graph.edges.select { |e| REPO_VIEW_TYPES.include?(e[:type]) })
      end

      def render_data_flow
        build_dot(@graph.edges.select { |e| %i[publishes consumes db_access].include?(e[:type]) })
      end

      def render_http
        build_dot(@graph.edges.select { |e| %i[http_call http_proxy].include?(e[:type]) })
      end

      def write_all(output_dir)
        require "fileutils"
        FileUtils.mkdir_p(output_dir)
        File.write(File.join(output_dir, "system.dot"), render_system)
        File.write(File.join(output_dir, "repos.dot"), render_repos)
        File.write(File.join(output_dir, "data-flow.dot"), render_data_flow)
        File.write(File.join(output_dir, "http.dot"), render_http)
      end

      private

      def build_dot(edges)
        lines = ['digraph vizult {', '  graph [rankdir=LR];', '  node [fontname="Helvetica", fontsize=10];']
        used = edges.flat_map { |e| [e[:from], e[:to]] }.uniq
        used.each do |id|
          n = @graph.nodes[id]
          next unless n

          nid = dot_id(id)
          shape = case n[:type]
                  when :database then "cylinder"
                  when :stream then "note"
                  else "box"
                  end
          label = escape_dot(n[:label].to_s)
          lines << "  #{nid} [label=\"#{label}\", shape=#{shape}];"
        end

        edges.each do |e|
          next unless @graph.nodes[e[:from]] && @graph.nodes[e[:to]]

          lbl = "#{e[:type]} (#{e[:confidence]})".gsub('"', '\"')
          extra = []
          extra << "style=dashed" << 'color="#888888"' if inferred_weak_edge?(e)
          extra << 'color="#1a7f37"' << "penwidth=2" if e.dig(:metadata, :merged_scan)
          attr = extra.empty? ? "" : ", #{extra.join(", ")}"
          lines << "  #{dot_id(e[:from])} -> #{dot_id(e[:to])} [label=\"#{lbl}\"#{attr}];"
        end
        lines << "}"
        lines.join("\n")
      end

      def dot_id(str)
        "n_" + str.to_s.gsub(/[^\w]/, "_").sub(/\A(\d)/, "x\\1")
      end

      def escape_dot(s)
        s.gsub(/["\\\n\r]/, " ")[0, 120]
      end

      def inferred_weak_edge?(e)
        e[:type] == :adjacent_clone || e[:type] == :same_org || e.dig(:metadata, :inference)
      end
    end
  end
end

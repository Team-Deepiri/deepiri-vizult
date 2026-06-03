# frozen_string_literal: true

module DeepiriVizult
  module Renderers
    class MermaidRenderer
      def initialize(graph)
        @graph = graph
      end

      def render_system
        build_chart(@graph.edges)
      end

      REPO_VIEW_TYPES = %i[
        contains imports adjacent_clone same_org manifest_ref scan_overlay
      ].freeze

      def render_repos
        build_chart(@graph.edges.select { |e| REPO_VIEW_TYPES.include?(e[:type]) })
      end

      def render_data_flow
        build_chart(@graph.edges.select { |e| %i[publishes consumes db_access].include?(e[:type]) })
      end

      def render_http
        build_chart(@graph.edges.select { |e| %i[http_call http_proxy].include?(e[:type]) })
      end

      def write_all(output_dir)
        require 'fileutils'
        FileUtils.mkdir_p(output_dir)
        File.write(File.join(output_dir, 'system.mmd'), render_system)
        File.write(File.join(output_dir, 'repos.mmd'), render_repos)
        File.write(File.join(output_dir, 'data-flow.mmd'), render_data_flow)
        File.write(File.join(output_dir, 'http.mmd'), render_http)
      end

      private

      def build_chart(edges)
        lines = ['flowchart LR']
        used_ids = edges.flat_map { |e| [e[:from], e[:to]] }.uniq
        used_ids.each do |id|
          n = @graph.nodes[id]
          next unless n

          safe = mermaid_id(id)
          shape = case n[:type]
                  when :database
                    "[(#{escape_label(n[:label])})]"
                  when :stream
                    "{{#{escape_label(n[:label])}}}"
                  else
                    "[#{escape_label(n[:label])}]"
                  end
          lines << "  #{safe}#{shape}"
        end

        edges.each do |e|
          from = mermaid_id(e[:from])
          to = mermaid_id(e[:to])
          label = e[:type].to_s.tr('_', ' ')
          arrow = inferred_weak_edge?(e) ? '-.->' : '-->'
          lines << "  #{from} #{arrow}|#{label}| #{to}"
        end

        lines.join("\n")
      end

      def mermaid_id(str)
        str.to_s.gsub(/[^\w]/, '_').sub(/\A(\d)/, 'n\\1')
      end

      def escape_label(str)
        str.to_s.gsub(/["\n]/, ' ').strip[0, 80]
      end

      def inferred_weak_edge?(e)
        e[:type] == :adjacent_clone || e[:type] == :same_org || e.dig(:metadata, :inference)
      end
    end
  end
end

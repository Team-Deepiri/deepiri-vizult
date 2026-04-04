# frozen_string_literal: true

require "csv"

module DeepiriVizult
  module Renderers
    class CsvRenderer
      HEADERS = %w[from to type confidence source_file line_number].freeze

      def initialize(graph)
        @graph = graph
      end

      def render
        CSV.generate do |csv|
          csv << HEADERS
          @graph.edges.each do |e|
            csv << [
              e[:from],
              e[:to],
              e[:type],
              e[:confidence],
              e[:source_file],
              e[:line_number]
            ]
          end
        end
      end

      def write(path)
        File.write(path, render, encoding: "UTF-8")
      end
    end
  end
end

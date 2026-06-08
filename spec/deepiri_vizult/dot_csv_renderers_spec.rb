# frozen_string_literal: true

require 'spec_helper'
require 'deepiri_vizult/renderers/dot_renderer'
require 'deepiri_vizult/renderers/csv_renderer'

RSpec.describe 'export renderers' do
  let(:graph) do
    g = DeepiriVizult::Graph.new
    g.add_node(id: 'service:a', type: :service, label: 'a')
    g.add_node(id: 'service:b', type: :service, label: 'b')
    g.add_edge(from: 'service:a', to: 'service:b', type: :http_call, confidence: :high, source_file: 'f.ts',
               line_number: 2)
    g
  end

  it 'DotRenderer emits digraph' do
    dot = DeepiriVizult::Renderers::DotRenderer.new(graph).render_system
    expect(dot).to include('digraph vizult')
    expect(dot).to include('->')
  end

  it 'CsvRenderer emits header and rows' do
    csv = DeepiriVizult::Renderers::CsvRenderer.new(graph).render
    lines = csv.lines
    expect(lines.first).to include('from')
    expect(lines.first).to include('confidence')
    expect(lines.size).to be >= 2
  end
end

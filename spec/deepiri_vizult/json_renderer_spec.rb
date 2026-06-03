# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'deepiri_vizult/graph'
require 'deepiri_vizult/renderers/json_renderer'

RSpec.describe DeepiriVizult::Renderers::JsonRenderer do
  it 'outputs graph wrapper with string keys for diff tooling' do
    g = DeepiriVizult::Graph.new
    g.add_node(id: 'service:a', type: :service, label: 'a')
    json = JSON.parse(described_class.new(g).render)
    expect(json['graph']).to be_a(Hash)
    expect(json['graph']['nodes'].size).to eq(1)
    expect(json['meta']['node_count']).to eq(1)
  end
end

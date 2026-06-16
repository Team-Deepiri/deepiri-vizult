# frozen_string_literal: true

require 'spec_helper'
require 'deepiri_vizult/service_registry'
require 'deepiri_vizult/resolvers/url_resolver'

RSpec.describe DeepiriVizult::ServiceRegistry do
  it 'registers services and resolves URLs' do
    r = described_class.new
    r.register('auth', hostnames: ['auth'], ports: { container: 5001 })
    r.register('core-api', hostnames: ['core-api'], ports: { container: 5000 })
    res = DeepiriVizult::UrlResolver.new(r)
    expect(res.resolve_service('http://core-api:5000')).to eq('core-api')
    expect(res.resolve_service('http://auth:5001')).to eq('auth')
  end
end

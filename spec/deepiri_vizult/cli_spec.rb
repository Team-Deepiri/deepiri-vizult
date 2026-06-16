# frozen_string_literal: true

require 'spec_helper'
require 'deepiri_vizult/cli'

RSpec.describe DeepiriVizult::CLI do
  it 'exposes expected commands' do
    expect(described_class.all_commands.keys).to include(
      'scan', 'render', 'open', 'query', 'diff', 'version'
    )
  end
end

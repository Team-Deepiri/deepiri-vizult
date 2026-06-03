# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'spec_helper'
require 'deepiri_vizult/sibling_roots'

RSpec.describe DeepiriVizult::SiblingRoots do
  let(:parent) { Dir.mktmpdir('vizult-sib-roots') }

  after { FileUtils.remove_entry(parent) }

  it 'returns other git directories under the same parent' do
    main = File.join(parent, 'main')
    other = File.join(parent, 'other')
    FileUtils.mkdir_p(File.join(main, '.git'))
    FileUtils.mkdir_p(File.join(other, '.git'))

    paths = described_class.list(main).map(&:to_s)
    expect(paths).to include(other)
    expect(paths).not_to include(main)
  end
end

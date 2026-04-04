# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tmpdir"
require "spec_helper"
require "deepiri_vizult/submodule_paths"

RSpec.describe DeepiriVizult::SubmodulePaths do
  let(:tmpdir) { Dir.mktmpdir("vizult-sub") }

  after { FileUtils.remove_entry(tmpdir) }

  it "lists submodule checkout paths from .gitmodules" do
    File.write(File.join(tmpdir, ".gitmodules"), <<~INI)
      [submodule "child"]
        path = child
        url = git@github.com:x/child.git
    INI
    FileUtils.mkdir_p(File.join(tmpdir, "child"))

    paths = described_class.list(tmpdir)
    expect(paths).to include(Pathname.new(File.join(tmpdir, "child")).expand_path)
  end
end

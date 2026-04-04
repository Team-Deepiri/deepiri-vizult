# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  # Git checkouts alongside the scan root (same parent directory).
  module SiblingRoots
    module_function

    def list(root)
      root = Pathname.new(root).expand_path
      return [] unless root.parent.directory?

      out = []
      root.parent.each_child do |child|
        next unless child.directory?
        next unless child.join(".git").exist?
        next if child.expand_path == root.expand_path

        out << child
      end
      out
    end
  end
end

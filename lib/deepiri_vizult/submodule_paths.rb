# frozen_string_literal: true

require 'pathname'

module DeepiriVizult
  # Resolves checkout paths from .gitmodules under a repo root.
  module SubmodulePaths
    module_function

    def each_under(root)
      root = Pathname.new(root).expand_path
      Pathname.glob(root.join('**/.gitmodules')).each do |gm|
        current = nil
        File.foreach(gm, encoding: 'UTF-8') do |line|
          if (m = line.match(/^\[submodule "([^"]+)"\]/))
            current = m[1]
          elsif current && (m = line.match(/^\s*path\s*=\s*(.+)/))
            rel = m[1].strip
            full = gm.dirname.join(rel).expand_path
            yield full if full.directory?
            current = nil
          end
        end
      end
    end

    def list(root)
      out = []
      each_under(root) { |p| out << p }
      out.uniq
    end
  end
end

# frozen_string_literal: true

require 'pathname'
require 'open3'

module DeepiriVizult
  module Scanners
    # Lists the files that make up a project using git's own ignore rules, so
    # vendored / build / cache directories (node_modules, .venv, dist, …) are
    # skipped without any hardcoded list — each repo's .gitignore is the source
    # of truth. Returns tracked files (including populated submodules) plus
    # untracked-but-not-ignored files. Falls back to a plain recursive walk when
    # the root is not a git work tree.
    module ProjectFiles
      module_function

      # @param root [String, Pathname]
      # @return [Array<Pathname>] absolute paths to project files
      def list(root)
        root = Pathname.new(root).expand_path
        git_list(root) || glob_list(root)
      end

      def git_list(root)
        return nil unless git_repo?(root)

        rels = run_git(root, 'ls-files', '--recurse-submodules', '-z') +
               run_git(root, 'ls-files', '--others', '--exclude-standard', '-z')
        rels.uniq.map { |rel| root.join(rel) }.select(&:file?)
      end

      def git_repo?(root)
        out, status = Open3.capture2e('git', '-C', root.to_s, 'rev-parse', '--is-inside-work-tree')
        status.success? && out.strip == 'true'
      rescue StandardError
        false
      end

      def run_git(root, *args)
        out, status = Open3.capture2('git', '-C', root.to_s, *args)
        return [] unless status.success?

        out.split("\x00").reject(&:empty?)
      rescue StandardError
        []
      end

      def glob_list(root)
        Dir.glob(root.join('**/*'), File::FNM_DOTMATCH)
           .select { |p| File.file?(p) }
           .map { |p| Pathname.new(p) }
      end
    end
  end
end

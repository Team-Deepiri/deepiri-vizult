# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  module Scanners
    class GitScanner
      GIT_REMOTE_RE = %r{\Agit@([^:]+):([^/]+)/([^.]+)(?:\.git)?\z}.freeze
      HTTPS_REMOTE_RE = %r{\Ahttps?://([^/]+)/([^/]+)/([^/.]+)}.freeze

      def initialize(root:, graph:, siblings: true)
        @root = Pathname.new(root).expand_path
        @graph = graph
        @siblings = siblings
      end

      def scan
        scan_repo(@root, repo_id_for(@root))

        if @siblings && @root.parent.directory?
          @root.parent.each_child do |child|
            next unless child.directory?

            gitdir = child.join(".git")
            next unless gitdir.exist?

            next if child.expand_path == @root.expand_path

            scan_repo(child, repo_id_for(child))
          end
        end

        scan_gitmodules
      end

      private

      def repo_id_for(path)
        "repo:#{path.basename}"
      end

      def scan_repo(path, repo_id)
        return if @graph.node?(repo_id)

        @graph.add_node(id: repo_id, type: :repo, label: path.basename.to_s, metadata: { path: path.to_s })
        extract_org_from_git(path, repo_id)
      end

      def extract_org_from_git(path, repo_id)
        config = path.join(".git", "config")
        return unless config.file?

        text = File.read(config, encoding: "UTF-8")
        text.scan(/^\s*url\s*=\s*(.+)$/i) do |m|
          url = m[0].strip
          org = parse_org_from_remote(url)
          next unless org

          meta = @graph.nodes[repo_id][:metadata]
          meta[:remotes] ||= []
          meta[:remotes] << url unless meta[:remotes].include?(url)
          meta[:org] ||= org
        end
      end

      def parse_org_from_remote(url)
        if (m = url.match(GIT_REMOTE_RE))
          return m[2]
        end
        if (m = url.match(HTTPS_REMOTE_RE))
          return m[2]
        end
        nil
      end

      def scan_gitmodules
        Pathname.glob(@root.join("**/.gitmodules")).each do |gm|
          owner_id = ensure_owner_repo(gm.dirname)
          current_sub = nil
          File.foreach(gm, encoding: "UTF-8") do |line|
            if (m = line.match(/^\[submodule "([^"]+)"\]/))
              current_sub = m[1]
            elsif current_sub && (m = line.match(/^\s*path\s*=\s*(.+)/))
              rel = m[1].strip
              full = gm.dirname.join(rel)
              base = File.basename(rel)
              rid = "repo:#{base}"
              unless @graph.node?(rid)
                @graph.add_node(
                  id: rid,
                  type: :repo,
                  label: base,
                  metadata: { path: full.to_s, submodule: true }
                )
              end
              link_submodule(owner_id, rid, gm)
              current_sub = nil
            end
          end
        end
      end

      # Ensures a repo node exists for the directory that owns a .gitmodules file. The dir basename
      # is treated as the repo name (matches the rest of the pipeline, which keys repo ids off
      # path basenames). Returns the repo id.
      def ensure_owner_repo(dir)
        rid = "repo:#{dir.basename}"
        unless @graph.node?(rid)
          @graph.add_node(
            id: rid,
            type: :repo,
            label: dir.basename.to_s,
            metadata: { path: dir.to_s }
          )
        end
        rid
      end

      def link_submodule(owner_id, sub_id, gm_path)
        return if owner_id == sub_id
        return if @graph.edges.any? { |e| e[:from] == owner_id && e[:to] == sub_id && e[:type] == :contains }

        @graph.add_edge(
          from: owner_id,
          to: sub_id,
          type: :contains,
          confidence: :high,
          source_file: gm_path.to_s,
          metadata: { submodule: true }
        )
      end
    end
  end
end

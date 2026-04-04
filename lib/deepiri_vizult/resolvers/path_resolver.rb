# frozen_string_literal: true

require "pathname"

module DeepiriVizult
  # Maps a source file path to owning service using longest matching build context.
  class PathResolver
    def initialize(registry)
      @registry = registry
    end

    # @param file_path [String, Pathname] absolute or relative path
    # @param root [Pathname] scan root
    def owning_service(file_path, root)
      abs = Pathname.new(file_path).expand_path
      root = Pathname.new(root).expand_path
      best = nil
      best_len = -1

      @registry.services.each do |name, data|
        data[:source_dirs].each do |dir|
          next unless dir

          d = dir.is_a?(Pathname) ? dir.expand_path : Pathname.new(dir).expand_path(root)
          next unless abs.to_s.start_with?(d.to_s)

          len = d.to_s.length
          if len > best_len
            best_len = len
            best = name
          end
        end
      end
      best
    end
  end
end

# frozen_string_literal: true

module DeepiriVizult
  class EnvResolver
    def initialize(registry)
      @registry = registry
      @url_resolver = UrlResolver.new(registry)
    end

    # Given env var name and optional default value string from code, return target service id or nil
    def resolve(var_name, default_value = nil)
      var = var_name.to_s.upcase
      @registry.services.each_value do |data|
        data[:env_refs].each do |k, v|
          next unless k.upcase == var

          return @url_resolver.resolve_service(v)
        end
      end
      @url_resolver.resolve_service(default_value) if default_value
    end
  end
end

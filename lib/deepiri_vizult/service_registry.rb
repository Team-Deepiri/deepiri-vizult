# frozen_string_literal: true

require 'pathname'

module DeepiriVizult
  # Built from compose/k8s only. No hardcoded service names.
  class ServiceRegistry
    attr_reader :services

    # @services[service_name] = {
    #   hostnames: Set,
    #   ports: { host: Integer|nil, container: Integer|nil },
    #   source_dirs: Array<Pathname>, # absolute paths from build.context
    #   compose_files: Array<String>,
    #   env_refs: Hash<String, String> # VAR_NAME => value
    # }
    def initialize
      @services = {}
    end

    def register(service_name, hostnames: [], ports: {}, source_dirs: [], compose_file: nil, env_refs: {})
      key = service_name.to_s
      @services[key] ||= {
        hostnames: [],
        ports: { host: nil, container: nil },
        source_dirs: [],
        compose_files: [],
        env_refs: {}
      }
      entry = @services[key]
      Array(hostnames).each { |h| entry[:hostnames] << h.to_s unless entry[:hostnames].include?(h.to_s) }
      entry[:hostnames] << key unless entry[:hostnames].include?(key)
      entry[:ports][:host] = ports[:host] if ports[:host]
      entry[:ports][:container] = ports[:container] if ports[:container]
      Array(source_dirs).each do |d|
        p = d.is_a?(Pathname) ? d : Pathname.new(d)
        entry[:source_dirs] << p.expand_path unless entry[:source_dirs].any? { |x| x.to_s == p.expand_path.to_s }
      end
      entry[:compose_files] << compose_file if compose_file && !entry[:compose_files].include?(compose_file)
      env_refs.each { |k, v| entry[:env_refs][k.to_s] = v.to_s }
    end

    def merge_env_refs(service_name, hash)
      return unless @services[service_name.to_s]

      hash.each { |k, v| @services[service_name.to_s][:env_refs][k.to_s] = v.to_s }
    end

    # Find service id by hostname (and optional port)
    def find_by_hostname(hostname, port = nil)
      host = hostname.to_s.downcase
      @services.each do |name, data|
        next unless data[:hostnames].any? { |h| h.downcase == host }

        if port && data[:ports][:container] && data[:ports][:container] != port.to_i && data[:ports][:container]
          # allow match if port not specified on registry
          next
        end

        return name
      end
      nil
    end

    def all_hostnames
      @services.values.flat_map { |d| d[:hostnames] }.uniq
    end

    def source_dir_for_service(name)
      @services[name.to_s]&.dig(:source_dirs)&.first
    end
  end
end

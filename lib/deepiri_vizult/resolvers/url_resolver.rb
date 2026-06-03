# frozen_string_literal: true

require 'uri'

module DeepiriVizult
  class UrlResolver
    def initialize(registry)
      @registry = registry
    end

    # Returns service name string or nil
    def resolve_service(url_string)
      return nil if url_string.nil? || url_string.to_s.strip.empty?

      s = url_string.to_s.strip
      # strip template ${VAR}
      s = s.gsub(/\$\{[^}]+\}/, '').gsub(/%\([^)]+\)/, '')
      return nil if s.empty? || s == 'http://' || s == 'https://'

      uri = URI.parse((s.match?(%r{\A[\w+.-]+://}) ? s : "http://#{s}"))
      host = uri.host&.downcase
      port = uri.port
      return nil unless host

      @registry.services.each do |name, data|
        data[:hostnames].each do |h|
          next unless h.downcase == host

          cport = data[:ports][:container]
          if port && cport && port != cport && port != 80 && port != 443 && cport
            # still match if registry has no container port
            next
          end

          return name
        end
      end

      # substring match for service-name as hostname prefix
      @registry.services.each_key do |name|
        return name if host == name.downcase || host.start_with?("#{name.downcase}.")
      end

      nil
    rescue URI::InvalidURIError
      nil
    end

    def extract_urls_from_string(str)
      str.scan(%r{(?:https?|wss?)://[^\s'"`]+}).flatten
    end
  end
end

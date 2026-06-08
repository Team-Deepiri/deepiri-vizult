# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'deepiri-vizult'
  spec.version       = '0.4.1'
  spec.authors       = ['Team-Deepiri']
  spec.summary       = 'Local architecture graph: scan compose, k8s, and code; emit Mermaid + HTML'
  spec.description   = <<~DESC
    CLI tool that walks a microservice repo, discovers services from Docker Compose and Kubernetes,
    correlates HTTP/stream/DB edges from source code, and outputs graph.json, Mermaid, and a static HTML viewer.
  DESC
  spec.homepage       = 'https://github.com/Team-Deepiri/deepiri-vizult'
  spec.license        = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.0.0'
  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*', 'exe/*', 'README.md', 'ROADMAP.md', 'docs/**/*.md', 'LICENSE',
                   'NOTICE', 'Rakefile', '*.gemspec', 'spec/**/*']
  spec.bindir        = 'exe'
  spec.executables   = ['vizult']
  spec.require_paths = ['lib']

  spec.add_dependency 'csv'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.75'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.6'
end

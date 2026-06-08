# frozen_string_literal: true

require 'English'
require 'thor'
require 'pathname'
require 'json'
require 'shellwords'

require_relative '../deepiri_vizult'

module DeepiriVizult
  class CLI < Thor
    package_name 'vizult'

    def self.exit_on_failure?
      true
    end

    class_option :depth, type: :numeric, default: 12, desc: 'Max directory depth for scans'

    desc 'version', 'Print version'
    def version
      say DeepiriVizult::VERSION
    end

    desc 'scan [PATH]', 'Scan a directory and build the architecture graph'
    option :siblings, type: :boolean, default: true, desc: 'Include sibling git repos in parent directory'
    option :no_siblings, type: :boolean, default: false, desc: 'Skip sibling repo discovery'
    option :siblings_scan, type: :boolean, default: false,
                           desc: 'Run full scan per sibling repo and merge (sb* prefixed ids)'
    option :infer_org_links, type: :boolean, default: false,
                             desc: 'Add low-confidence same_org edges between sibling pairs sharing git org'
    option :org, type: :string, desc: 'GitHub org: add remote repo nodes via gh CLI'
    option :submodules, type: :boolean, default: false,
                        desc: 'Also scan each .gitmodules checkout and merge with prefixed node ids'
    option :format, type: :string, default: 'all', enum: %w[all json mermaid html dot csv]
    def scan(path = '.')
      root = Pathname.new(path).expand_path
      scanner = build_scanner(root)
      scanner.run
      out = output_dir(root)
      write_outputs(scanner.graph, out.to_s, options[:format] || 'all')
      say "vizult: wrote #{out}/ (#{options[:format]})"
    end

    desc 'render [PATH]', 'Same as scan: discover graph and write outputs'
    option :siblings, type: :boolean, default: true
    option :no_siblings, type: :boolean, default: false
    option :siblings_scan, type: :boolean, default: false
    option :infer_org_links, type: :boolean, default: false
    option :org, type: :string
    option :submodules, type: :boolean, default: false
    option :format, type: :string, default: 'all', enum: %w[all json mermaid html dot csv]
    def render(path = '.')
      invoke :scan, [path], render_invoke_options
    end

    desc 'open', 'Scan current directory, render all formats, open HTML viewer in default browser'
    option :siblings, type: :boolean, default: true
    option :no_siblings, type: :boolean, default: false
    option :siblings_scan, type: :boolean, default: false
    option :infer_org_links, type: :boolean, default: false
    option :submodules, type: :boolean, default: false
    def open
      root = Pathname.new('.').expand_path
      scanner = build_scanner(root)
      scanner.run
      out = output_dir(root)
      write_outputs(scanner.graph, out.to_s, 'all')
      html = "#{out}index.html"
      unless html.file?
        say "vizult: failed to write #{html}", :red
        exit 1
      end
      ok = if RUBY_PLATFORM.match?(/mswin|mingw/i)
             system('cmd', '/c', 'start', '', html.to_s)
           elsif RUBY_PLATFORM.match?(/darwin/i)
             system('open', html.to_s)
           else
             system('xdg-open', html.to_s)
           end
      say "vizult: opened #{html}" if ok
    end

    desc 'query NAME', 'Print edges whose endpoints match substring'
    def query(name)
      scanner = Scanner.new(
        root: Pathname.pwd,
        siblings: false,
        submodules: false,
        siblings_scan: false,
        infer_org_links: false,
        max_depth: options[:depth] || 12,
        org: nil
      )
      scanner.run
      q = name.to_s.downcase
      found = false
      scanner.graph.edges.each do |e|
        next unless e[:from].downcase.include?(q) || e[:to].downcase.include?(q)

        found = true
        say "#{e[:from]} --[#{e[:type]}]--> #{e[:to]}  #{e[:confidence]}  #{e[:source_file]}"
      end
      say '(no matches)' unless found
    end

    desc 'diff REF', 'Compare vizult-output/graph.json to the same path at git REF (edge counts + new/removed ids)'
    def diff(ref = 'HEAD')
      path = "#{Pathname.pwd}vizult-output/graph.json"
      unless path.file?
        say "No #{path}; run vizult scan first.", :red
        exit 1
      end

      current = JSON.parse(File.read(path, encoding: 'UTF-8'))
      old_raw = `git show #{Shellwords.escape(ref)}:vizult-output/graph.json 2>/dev/null`
      unless $CHILD_STATUS.success? && !old_raw.strip.empty?
        say "Could not read vizult-output/graph.json at #{ref} (commit graph or run scan from repo root).", :yellow
        exit 2
      end

      previous = JSON.parse(old_raw)
      cur_edges = current.dig('graph', 'edges') || []
      prev_edges = previous.dig('graph', 'edges') || []
      cur_ids = cur_edges.map { |e| [e['from'], e['to'], e['type']].join('->') }.to_h { |x| [x, true] }
      prev_ids = prev_edges.map { |e| [e['from'], e['to'], e['type']].join('->') }.to_h { |x| [x, true] }

      added = cur_ids.keys - prev_ids.keys
      removed = prev_ids.keys - cur_ids.keys
      say "Edges at #{ref}: #{prev_edges.size}  |  now: #{cur_edges.size}"
      say "Added (#{added.size}):"
      added.first(50).each { |x| say "  + #{x}" }
      say '  ...' if added.size > 50
      say "Removed (#{removed.size}):"
      removed.first(50).each { |x| say "  - #{x}" }
      say '  ...' if removed.size > 50
    end

    private

    def siblings_effective
      return true if options[:siblings_scan]
      return false if options[:no_siblings]

      options.fetch(:siblings, true)
    end

    def build_scanner(root)
      Scanner.new(
        root: root,
        siblings: siblings_effective,
        submodules: options[:submodules],
        siblings_scan: options[:siblings_scan],
        infer_org_links: options[:infer_org_links],
        max_depth: options[:depth] || 12,
        org: options[:org]
      )
    end

    def render_invoke_options
      {
        format: options[:format],
        siblings: options[:siblings],
        no_siblings: options[:no_siblings],
        submodules: options[:submodules],
        siblings_scan: options[:siblings_scan],
        infer_org_links: options[:infer_org_links],
        org: options[:org],
        depth: options[:depth]
      }
    end

    def output_dir(root)
      "#{root}vizult-output"
    end

    def write_outputs(graph, out_dir, format)
      require 'fileutils'
      FileUtils.mkdir_p(out_dir)
      fmt = format.to_s
      Renderers::JsonRenderer.new(graph).write(File.join(out_dir, 'graph.json')) if %w[all json].include?(fmt)
      Renderers::MermaidRenderer.new(graph).write_all(out_dir) if %w[all mermaid].include?(fmt)
      Renderers::HtmlRenderer.new(graph).write(File.join(out_dir, 'index.html')) if %w[all html].include?(fmt)
      Renderers::DotRenderer.new(graph).write_all(out_dir) if %w[all dot].include?(fmt)
      return unless %w[all csv].include?(fmt)

      Renderers::CsvRenderer.new(graph).write(File.join(out_dir, 'edges.csv'))
    end
  end
end

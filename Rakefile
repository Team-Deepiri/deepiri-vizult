# frozen_string_literal: true

begin
  require "bundler/gem_tasks"
rescue LoadError
  # optional when developing without Bundler
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task default: :spec

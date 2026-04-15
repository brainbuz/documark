# frozen_string_literal: true

require 'rake/testtask'

def apply_test_options(task)
  opts = ENV['TESTOPTS'].to_s.strip
  task.options = opts.split(/\s+/) unless opts.empty?
end

desc 'Run all tests'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  apply_test_options(t)
end

namespace :test do
  desc 'Run CLI integration tests only'
  Rake::TestTask.new(:cli) do |t|
    t.libs << 'test'
    t.pattern = 'test/cli_test.rb'
    apply_test_options(t)
  end

  desc 'Run all tests with coverage'
  task :coverage do
    original_coverage = ENV['COVERAGE']
    begin
      ENV['COVERAGE'] = '1'
      Rake::Task[:test].reenable
      Rake::Task[:test].invoke

      require 'simplecov'
      SimpleCov.collate Dir['coverage/.resultset*.json'] do
        track_files 'lib/**/*.rb'
      end
    ensure
      ENV['COVERAGE'] = original_coverage
    end
  end
end

task default: :test

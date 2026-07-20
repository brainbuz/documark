# frozen_string_literal: true

# Add plugin lib to load path so 'require documark/...' finds plugin files
$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
# Add core lib to load path so plugin tests use in-repo Documark sources.
$LOAD_PATH.unshift(File.expand_path('../../../lib', __dir__))

if ENV['COVERAGE'] == '1'
	require 'simplecov'
	SimpleCov.command_name "tests:#{Process.pid}"
	SimpleCov.start do
		track_files 'lib/**/*.rb'
		track_files '../../../lib/**/*.rb'
	end
end

require 'minitest/autorun'

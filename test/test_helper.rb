# frozen_string_literal: true

if ENV['COVERAGE'] == '1'
	require 'simplecov'
	SimpleCov.command_name "tests:#{Process.pid}"
	SimpleCov.start do
		track_files 'lib/**/*.rb'
	end
end

require 'minitest/autorun'

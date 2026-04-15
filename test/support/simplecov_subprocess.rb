# frozen_string_literal: true

return unless ENV['COVERAGE'] == '1'

require 'simplecov'

# Distinguish each spawned CLI process in resultset output.
SimpleCov.command_name "cli:#{Process.pid}"

SimpleCov.start do
  track_files 'lib/**/*.rb'
end

# frozen_string_literal: true

source 'https://rubygems.org'

# Pull runtime and shared development dependencies from documark.gemspec.
gemspec

# In monorepo development/testing, always resolve Documark plugin gems locally
# so CI and containers test the checked-out code, not published gems.
# Set DOCUMARK_RELEASE_DEPS=1 to emulate release-style dependency resolution.
if ENV['DOCUMARK_RELEASE_DEPS'] != '1'
  group :plugin_asciidoc do
    gem 'documark-plugin-asciidoc', path: 'plugins/asciidoc'
  end
end

group :development, :test do
  gem 'rubocop', require: false
end

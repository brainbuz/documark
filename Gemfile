# frozen_string_literal: true

source 'https://rubygems.org'

gem 'hexapdf'
gem 'kramdown'
gem 'psych'
gem 'slop'
gem 'erb'

group :test do
  gem 'minitest'
  gem 'rake'
  gem 'simplecov', require: false
end

# Optional plugin dependencies. These are NOT loaded by the main documark
# code path; the asciidoc plugin requires them at plugin-load time. Install
# them only if you intend to use that plugin (or run its tests):
#   bundle install --with plugin_asciidoc
# Or skip them if you don't:
#   bundle install --without plugin_asciidoc
group :plugin_asciidoc, optional: true do
  gem 'asciidoctor'
  gem 'nokogiri'
end

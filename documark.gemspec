# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'documark'
  spec.version       = '0.1.0'
  spec.authors       = ['John Karr']
  spec.email         = ['brainbuz@gmail.com']
  spec.summary       = 'A document processor with pluggable rendering targets'
  spec.description   = 'Documark is a prototype document processor that renders ' \
                       'a YAML-driven document format to HTML, PDF, Markdown, and other formats.'
  spec.homepage      = 'https://github.com/brainbuz/documark'
  spec.license       = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.2.0'

  spec.files = Dir['{lib,bin}/**/*'] + ['documark.gemspec', 'README.md', 'LICENSE']
  spec.bindir = 'bin'
  spec.executables = ['documark']

  spec.add_dependency 'kramdown'
  spec.add_dependency 'hexapdf'
  spec.add_dependency 'psych'
  spec.add_dependency 'slop'
  spec.add_dependency 'erb'

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
end

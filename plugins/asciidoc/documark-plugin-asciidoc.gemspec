# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'documark-plugin-asciidoc'
  spec.version       = '0.1.0'
  spec.authors       = ['John Karr']
  spec.email         = ['brainbuz@gmail.com']
  spec.summary       = 'AsciiDoc plugin for Documark'
  spec.description   = 'Provides AsciiDoc and talltable features for Documark, ' \
                       'rendering AsciiDoc via Asciidoctor.'
  spec.homepage      = 'https://github.com/brainbuz/documark'
  spec.license       = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.2.0'

  spec.files = Dir['{lib}/**/*'] + ['documark-plugin-asciidoc.gemspec', 'README.md']

  spec.add_dependency 'documark', '>= 0.1.0'
  spec.add_dependency 'asciidoctor'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'logger' # bundled gem in Ruby 4.0+

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rake'
end

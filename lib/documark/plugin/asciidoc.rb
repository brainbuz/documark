# frozen_string_literal: true

# AsciiDoc plugin for Documark.
#
# Provides the 'asciidoc' and 'talltable' features. Renders AsciiDoc
# source to HTML via Asciidoctor, stripping structural CSS classes so
# the output inherits Documark's own styling. language-* classes on
# <code> and <pre> are preserved for syntax highlighter compatibility.
#
# Asciidoctor and Nokogiri are NOT loaded unless this plugin file is
# loaded. The main Documark library has no runtime dependency on either.

require 'asciidoctor'
require 'nokogiri'

module Documark
  module Plugin
    module Asciidoc
      module_function

      # Walk the HTML fragment, dropping every `class` attribute. On
      # <code> and <pre>, language-* tokens are kept so syntax-
      # highlighting hooks survive.
      def _strip_classes(html)
        doc = ::Nokogiri::HTML5.fragment(html)
        doc.traverse do |node|
          next unless node.element? && node.key?('class')

          if %w[code pre].include?(node.name)
            kept = node['class'].split(/\s+/).select { |c| c.start_with?('language-') }
            kept.empty? ? node.remove_attribute('class') : node['class'] = kept.join(' ')
          else
            node.remove_attribute('class')
          end
        end
        doc.to_html
      end

      def convert(content)
        html = ::Asciidoctor.convert(content, safe: :safe, header_footer: false)
        _strip_classes(html)
      end
    end
  end
end

Documark::Plugins.register('asciidoc', plugin: 'asciidoc',
  description: 'AsciiDoc includes and inline blocks via Asciidoctor') do |f|

  f.extends_include type: 'asciidoc', extensions: %w[.adoc .asciidoc] do |content, _args, _ctx|
    { content: Documark::Plugin::Asciidoc.convert(content), mode: :placeholder }
  end

  f.register_directive 'asciidoc', form: :block do |_args, content, _ctx|
    { content: Documark::Plugin::Asciidoc.convert(content), mode: :placeholder }
  end
end

# talltable: semantic alias for AsciiDoc-rendered tables (see todo.txt for planned enhancement).
Documark::Plugins.register('talltable', plugin: 'asciidoc',
  description: 'AsciiDoc block directive for tall/complex tables') do |f|

  f.register_directive 'talltable', form: :block do |_args, content, _ctx|
    { content: Documark::Plugin::Asciidoc.convert(content), mode: :placeholder }
  end
end

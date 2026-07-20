# frozen_string_literal: true

require_relative 'runtime'
require_relative 'conditionals'

module Documark
  module ExportClean
    module_function
    extend Documark::Runtime

    def cleanup_markdown_output(content)
      text = content.to_s.dup

      # Remove @{} block/section open tags and close markers — @{ attrs } or @{}
      text.gsub!(/^[ \t]*@\{[^}]*\}[ \t]*\n/, '')
      text.gsub!(/@\{[^}]*\}/, '')

      # Remove @[element attrs] open tags and @[/element] close tags
      text.gsub!(/^[ \t]*@\[[^\]]*\][ \t]*\n/, '')
      text.gsub!(/@\[[^\]]*\]/, '')

      # Remove @<element attrs> open tags and @</element> close tags
      text.gsub!(/^[ \t]*@<[^>]*>[ \t]*\n/, '')
      text.gsub!(/@<[^>]*>/, '')

      # Remove remaining full-line directives — @(toc), @( include 'x.md' ),
      # stray @( end ), etc. — entire line and its newline.
      text.gsub!(/^[ \t]*@\([^)]*\)[ \t]*\n/, '')

      # Remove inline index tags — @(# term)
      text.gsub!(/@\(#[^)]*\)/, '')

      # Reduce index shorthand — @#word — to the bare word
      text.gsub!(/@#\s*(\p{L}+)/, '\1')

      text
    end

    def write_markdown_output(output_path, body, data = {})
      resolved = Documark::Conditionals.resolve(body, data)
      ordie { File.write(output_path, cleanup_markdown_output(resolved)) }
    end
  end
end
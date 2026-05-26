# frozen_string_literal: true

require_relative 'runtime'

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

      text
    end

    def write_markdown_output(output_path, body)
      ordie { File.write(output_path, cleanup_markdown_output(body)) }
    end
  end
end
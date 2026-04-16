# frozen_string_literal: true

require_relative 'runtime'

module Documark
  module ExportClean
    module_function
    extend Documark::Runtime

    def cleanup_markdown_output(content)
      text = content.to_s.dup
      # Remove common kramdown attribute list syntax from block and inline usage.
      text.gsub!(/^[ \t]*\{:[^}\n]*\}[ \t]*\n/, '')
      text.gsub!(/[ \t]*\{:[^}\n]*\}/, '')
      text
    end

    def write_markdown_output(output_path, body)
      ordie { File.write(output_path, cleanup_markdown_output(body)) }
    end
  end
end
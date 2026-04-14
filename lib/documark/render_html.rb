# frozen_string_literal: true

require 'erb'
require 'kramdown'
require_relative 'runtime'

module Documark
  module RenderHtml
    module_function
    extend Documark::Runtime

    def compose_html(options, layout, data, html)
      template = File.read(File.expand_path('../documark/html.erb', __dir__))
      ERB.new(template).result_with_hash(options: options, layout: layout, data: data, html: html)
    end

    def cleanup_markdown_output(content)
      text = content.to_s
      # Remove common kramdown attribute list syntax from block and inline usage.
      text.gsub!(/^[ \t]*\{:[^}\n]*\}[ \t]*\n/, '')
      text.gsub!(/[ \t]*\{:[^}\n]*\}/, '')
      text
    end

    def render_page(options, layout, data, body)
      html = Kramdown::Document.new(body).to_html
      compose_html(options, layout, data, html)
    end

    def write_page(output_path, page)
      ordie { File.write(output_path, page) }
    end

    def write_markdown_output(output_path, body)
      ordie { File.write(output_path, cleanup_markdown_output(body)) }
    end
  end
end

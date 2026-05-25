# frozen_string_literal: true

require 'erb'
require 'kramdown'
require_relative 'runtime'
require_relative 'tag_processor'

module Documark
  module RenderHtml
    module_function
    extend Documark::Runtime

    def compose_html(options, layout, data, html)
      template = File.read(File.expand_path('../documark/html.erb', __dir__))
      ERB.new(template).result_with_hash(options: options, layout: layout, data: data, html: html)
    end

    def render_page(options, layout, data, body)
      opts    = (layout || {}).merge("input_path" => options["input"])
      prepped = ordie { Documark::TagProcessor.preprocess(body, opts) }
      # Propagate emission flags set by the tag processor back onto the
      # layout hash so downstream renderers can see them.
      if layout.is_a?(Hash)
        layout['toc_emitted']   = opts['toc_emitted']
        layout['index_emitted'] = opts['index_emitted']
      end
      html    = Kramdown::Document.new(prepped).to_html
      html    = Documark::TagProcessor.postprocess(html)
      compose_html(options, layout, data, html)
    end

    def write_page(output_path, page)
      ordie { File.write(output_path, page) }
    end
  end
end

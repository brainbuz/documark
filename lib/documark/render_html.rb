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
      prepped, registry = Documark::TagProcessor.preprocess(body)
      html = Kramdown::Document.new(prepped).to_html
      html = Documark::TagProcessor.postprocess(html, registry)
      compose_html(options, layout, data, html)
    end

    def write_page(output_path, page)
      ordie { File.write(output_path, page) }
    end
  end
end

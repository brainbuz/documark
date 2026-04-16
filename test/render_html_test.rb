# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/documark/render_html'

class DocumarkRenderHtmlTest < Minitest::Test
  def test_render_page_builds_full_html_document
    layout = {
      'stylesheets' => ['https://example.com/site.css'],
      'container_class' => 'container',
      'style' => '@media print {}'
    }
    data = {
      'title' => 'Render Test',
      'language' => 'en'
    }

    page = Documark::RenderHtml.render_page({}, layout, data, "# Hello\n")

    assert_includes page, '<!doctype html>'
    assert_includes page, '<title>Render Test</title>'
    assert_includes page, '<html lang="en">'
    assert_includes page, '<link rel="stylesheet" href="https://example.com/site.css">'
    assert_includes page, '<h1 id="hello">Hello</h1>'
  end
end

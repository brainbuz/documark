# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative '../lib/documark/render_html'

class DocumarkRenderHtmlTest < Minitest::Test
  def test_cleanup_markdown_output_removes_attribute_list_syntax
    source = <<~DOC
      # Heading
      {: .lead}

      Paragraph{: .tight}
    DOC

    cleaned = Documark::RenderHtml.cleanup_markdown_output(source)

    refute_includes cleaned, '{: .lead}'
    refute_includes cleaned, '{: .tight}'
    assert_includes cleaned, '# Heading'
    assert_includes cleaned, 'Paragraph'
  end

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

  def test_write_markdown_output_writes_cleaned_content
    Dir.mktmpdir('documark-render-test') do |tmpdir|
      output_path = File.join(tmpdir, 'out.md')

      Documark::RenderHtml.write_markdown_output(output_path, "Line{: .trim}\n")

      assert_equal "Line\n", File.read(output_path)
    end
  end
end

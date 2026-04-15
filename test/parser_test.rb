# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative '../lib/documark/parser'

class DocumarkParserTest < Minitest::Test
  def test_parse_header_parses_context_type_and_options
    parsed = Documark::Parser.parse_header('!! documark document option=baz mode=fast')

    assert_equal 'documark', parsed['context']
    assert_equal 'document', parsed['type']
    assert_equal 'baz', parsed['option']
    assert_equal 'fast', parsed['mode']
  end

  def test_read_header_rejects_non_documark_context
    error = assert_raises(StandardError) do
      Documark::Parser.read_header("!! other thing\n")
    end

    assert_equal 'File must begin with !! documark', error.message
  end

  def test_parse_data_section_applies_lang_alias
    data = Documark::Parser.parse_data_section("lang: ja\ntitle: test\n")

    assert_equal 'ja', data['lang']
    assert_equal 'ja', data['language']
    assert_equal 'test', data['title']
  end

  def test_parse_layout_section_extracts_frontmatter_and_style
    layout = <<~LAYOUT
      ---
      stylesheets:
        - https://example.com/base.css
      container_class: container
      ---
      @media print {
        @page { size: letter; }
      }
    LAYOUT

    parsed = Documark::Parser.parse_layout_section(layout)

    assert_equal ['https://example.com/base.css'], parsed['stylesheets']
    assert_equal 'container', parsed['container_class']
    assert_includes parsed['style'], '@media print'
  end

  def test_split_documark_sections_extracts_data_layout_and_body
    content = <<~DOC
      !! documark document
      !! data
      title: "Example"
      !! end
      !! layout
      ---
      container_class: container
      ---
      @media print {}
      !! end

      # Body
      hello
    DOC

    parsed = Documark::Parser.split_documark_sections(content)

    assert_includes parsed['data'], 'title: "Example"'
    assert_includes parsed['layout'], 'container_class: container'
    assert_includes parsed['body'], '# Body'
  end

  def test_read_layout_uses_explicit_default_layout_path
    Dir.mktmpdir('documark-parser-test') do |tmpdir|
      dml_path = File.join(tmpdir, 'custom.dml')
      File.write(dml_path, <<~DML)
        !! documark layout
        !! layout
        ---
        container_class: wrapper
        ---
        @media print {}
        !! end
      DML

      parsed = Documark::Parser.read_layout({}, { 'default_layout' => dml_path })

      assert_equal 'wrapper', parsed['container_class']
      assert_includes parsed['style'], '@media print'
    end
  end
end

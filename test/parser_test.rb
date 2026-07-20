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

  def test_split_documark_sections_extracts_assets_and_bounds_body
    content = <<~DOC
      !! documark document
      !! data
      title: "Example"
      !! end

      # Body
      hello
      !! assets
      SGVsbG8=
      d29ybGQ=
      !! end
    DOC

    parsed = Documark::Parser.split_documark_sections(content)

    assert_includes parsed['body'], '# Body'
    refute_includes parsed['body'], '!! assets'
    refute_includes parsed['body'], 'SGVsbG8='
    assert_includes parsed['assets'], 'SGVsbG8='
    assert_includes parsed['assets'], 'd29ybGQ='
  end

  def test_split_documark_sections_assets_nil_when_absent
    content = <<~DOC
      !! documark document
      !! data
      title: "Example"
      !! end

      # Body
    DOC

    parsed = Documark::Parser.split_documark_sections(content)

    assert_nil parsed['assets']
    assert_includes parsed['body'], '# Body'
  end

  def test_split_documark_sections_raises_for_unterminated_assets_block
    content = <<~DOC
      !! documark document
      !! data
      title: "Example"
      !! end
      # Body
      !! assets
      SGVsbG8=
    DOC

    error = assert_raises(StandardError) do
      Documark::Parser.split_documark_sections(content)
    end

    assert_equal 'Unterminated assets block', error.message
  end

  def test_split_documark_sections_rejects_content_after_assets_section
    content = <<~DOC
      !! documark document
      !! data
      title: "Example"
      !! end
      # Body
      !! assets
      SGVsbG8=
      !! end
      trailing junk
    DOC

    error = assert_raises(StandardError) do
      Documark::Parser.split_documark_sections(content)
    end

    assert_match(/content after !! assets section is not allowed/, error.message)
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

      result = Documark::Parser.read_layout({}, { 'default_layout' => dml_path })

      assert_equal 'wrapper', result['layout']['container_class']
      assert_includes result['layout']['style'], '@media print'
      assert_nil result['assets']
    end
  end

  def test_read_layout_returns_layout_and_assets_shape
    result = Documark::Parser.read_layout({})

    assert_kind_of Hash, result
    assert_equal %w[assets layout].sort, result.keys.sort
    assert_kind_of Hash, result['layout']
    # The built-in default.dml carries no assets section.
    assert_nil result['assets']
  end

  def test_read_layout_embedded_document_layout_wins_and_has_nil_assets
    Dir.mktmpdir('documark-parser-test') do |tmpdir|
      # A stationery file that would be used if the document had no layout.
      dms_path = File.join(tmpdir, 'paper.dms')
      File.write(dms_path, <<~DMS)
        !! documark layout
        !! layout
        ---
        container_class: stationery
        ---
        @media print {}
        !! end
        !! assets
        SGVsbG8=
        !! end
      DMS

      doc = { 'layout' => "---\ncontainer_class: embedded\n---\n@media screen {}\n" }
      result = Documark::Parser.read_layout(doc, { 'layout' => dms_path })

      assert_equal 'embedded', result['layout']['container_class']
      assert_nil result['assets'], 'embedded document layout carries no assets'
    end
  end

  def test_read_layout_stationery_file_returns_its_assets
    Dir.mktmpdir('documark-parser-test') do |tmpdir|
      dms_path = File.join(tmpdir, 'paper.dms')
      File.write(dms_path, <<~DMS)
        !! documark layout
        !! layout
        ---
        container_class: stationery
        ---
        @media print {}
        !! end
        !! assets
        SGVsbG8=
        d29ybGQ=
        !! end
      DMS

      result = Documark::Parser.read_layout({}, { 'layout' => dms_path })

      assert_equal 'stationery', result['layout']['container_class']
      refute_nil result['assets']
      assert_includes result['assets'], 'SGVsbG8='
      assert_includes result['assets'], 'd29ybGQ='
    end
  end

  def test_read_layout_prefers_layout_over_default_layout
    Dir.mktmpdir('documark-parser-test') do |tmpdir|
      explicit = File.join(tmpdir, 'explicit.dml')
      fallback = File.join(tmpdir, 'fallback.dml')
      File.write(explicit, <<~DML)
        !! documark layout
        !! layout
        ---
        container_class: explicit
        ---
        !! end
      DML
      File.write(fallback, <<~DML)
        !! documark layout
        !! layout
        ---
        container_class: fallback
        ---
        !! end
      DML

      result = Documark::Parser.read_layout({}, { 'layout' => explicit, 'default_layout' => fallback })

      assert_equal 'explicit', result['layout']['container_class']
    end
  end

  def test_read_document_warns_and_defaults_title_when_data_section_is_missing
    Dir.mktmpdir('documark-parser-test') do |tmpdir|
      input_path = File.join(tmpdir, 'no-data.dm')
      File.write(input_path, <<~DOC)
        !! documark document
        !! layout
        ---
        container_class: container
        ---
        @media print {}
        !! end

        # Body
      DOC

      document = nil
      stderr = capture_io do
        document = Documark::Parser.read_document(input_path)
      end.last

      assert_equal 'no-data.dm', document['data']['title']
      assert_match(/No data section found; defaulting title to no-data\.dm/, stderr)
    end
  end
end

# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/documark/parser'

class DocumarkParserErrorTest < Minitest::Test
  def test_split_documark_sections_rejects_empty_file
    error = assert_raises(StandardError) do
      Documark::Parser.split_documark_sections('')
    end

    assert_equal 'File must not be empty', error.message
  end

  def test_split_documark_sections_raises_for_unterminated_data_block
    content = <<~DOC
      !! documark document
      !! data
      title: "Broken"
    DOC

    error = assert_raises(StandardError) do
      Documark::Parser.split_documark_sections(content)
    end

    assert_equal 'Unterminated data block', error.message
  end

  def test_split_documark_sections_raises_for_unterminated_layout_block
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
    DOC

    error = assert_raises(StandardError) do
      Documark::Parser.split_documark_sections(content)
    end

    assert_equal 'Unterminated layout block', error.message
  end

  def test_parse_layout_section_requires_front_matter_start_delimiter
    error = assert_raises(StandardError) do
      Documark::Parser.parse_layout_section("container_class: container\n---\n")
    end

    assert_equal 'Layout section must start with ---', error.message
  end

  def test_parse_layout_section_requires_mapping_front_matter
    layout = <<~LAYOUT
      ---
      - one
      - two
      ---
      @media print {}
    LAYOUT

    error = assert_raises(StandardError) do
      Documark::Parser.parse_layout_section(layout)
    end

    assert_equal 'Layout front matter must be a mapping', error.message
  end
end

# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative '../lib/documark/export_clean'

class DocumarkExportCleanTest < Minitest::Test
  def test_cleanup_markdown_output_removes_block_brace_tag
    source = <<~DOC
      # Heading
      @{ .lead }

      Paragraph text.
    DOC

    cleaned = Documark::ExportClean.cleanup_markdown_output(source)

    refute_includes cleaned, '@{ .lead }'
    assert_includes cleaned, '# Heading'
    assert_includes cleaned, 'Paragraph text.'
  end

  def test_cleanup_markdown_output_removes_inline_brace_tag
    cleaned = Documark::ExportClean.cleanup_markdown_output("Text @{ .highlight } word @{} done.")
    refute_includes cleaned, '@{ .highlight }'
    refute_includes cleaned, '@{}'
    assert_includes cleaned, 'Text'
    assert_includes cleaned, 'word'
    assert_includes cleaned, 'done.'
  end

  def test_cleanup_markdown_output_removes_bracket_tag
    source = "@[aside .note]\nContent.\n@[/aside]\n"
    cleaned = Documark::ExportClean.cleanup_markdown_output(source)
    refute_includes cleaned, '@[aside .note]'
    refute_includes cleaned, '@[/aside]'
    assert_includes cleaned, 'Content.'
  end

  def test_cleanup_markdown_output_removes_angle_tag
    cleaned = Documark::ExportClean.cleanup_markdown_output("This is @<u> underlined @</u> text.")
    refute_includes cleaned, '@<u>'
    refute_includes cleaned, '@</u>'
    assert_includes cleaned, 'underlined'
    assert_includes cleaned, 'text.'
  end

  def test_cleanup_markdown_output_kramdown_syntax_is_preserved
    # Kramdown {: .class} is no longer stripped — it is unsupported in Documark
    # and passes through unchanged so authors can see it if it appears.
    source = "# Heading\n{: .lead}\n\nParagraph{: .tight}\n"
    cleaned = Documark::ExportClean.cleanup_markdown_output(source)
    assert_includes cleaned, '{: .lead}'
    assert_includes cleaned, '{: .tight}'
  end

  def test_write_markdown_output_writes_cleaned_content
    Dir.mktmpdir('documark-export-clean-test') do |tmpdir|
      output_path = File.join(tmpdir, 'out.md')

      Documark::ExportClean.write_markdown_output(output_path, "@{ .trim }Line@{}\n")

      assert_equal "Line\n", File.read(output_path)
    end
  end
end
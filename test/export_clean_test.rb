# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative '../lib/documark/export_clean'

class DocumarkExportCleanTest < Minitest::Test
  def test_cleanup_markdown_output_removes_attribute_list_syntax
    source = <<~DOC
      # Heading
      {: .lead}

      Paragraph{: .tight}
    DOC

    cleaned = Documark::ExportClean.cleanup_markdown_output(source)

    refute_includes cleaned, '{: .lead}'
    refute_includes cleaned, '{: .tight}'
    assert_includes cleaned, '# Heading'
    assert_includes cleaned, 'Paragraph'
  end

  def test_write_markdown_output_writes_cleaned_content
    Dir.mktmpdir('documark-export-clean-test') do |tmpdir|
      output_path = File.join(tmpdir, 'out.md')

      Documark::ExportClean.write_markdown_output(output_path, "Line{: .trim}\n")

      assert_equal "Line\n", File.read(output_path)
    end
  end
end
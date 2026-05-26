# frozen_string_literal: true

require_relative 'test_helper'

# Load core Documark modules from the main project's lib
$LOAD_PATH.unshift(File.expand_path('../../../../lib', __dir__))

require 'documark/plugins'
require 'documark/tag_processor'

# These tests exercise the in-repo AsciiDoc plugin. They are skipped
# automatically if asciidoctor / nokogiri are not installed (the user
# ran `bundle install --without plugin_asciidoc`), keeping the suite
# green for users who don't want the plugin's dependencies.
class PluginAsciidocTest < Minitest::Test
  ASCIIDOC_AVAILABLE = begin
    require 'asciidoctor'
    require 'nokogiri'
    require 'documark/plugin/asciidoc'
    true
  rescue LoadError
    false
  end

  FIXTURE_DIR = File.expand_path('fixtures', __dir__)

  def skip_unless_asciidoc
    skip 'asciidoctor / nokogiri not installed (plugin_asciidoc group)' unless ASCIIDOC_AVAILABLE
  end

  def test_plugin_registers_asciidoc_include_type
    skip_unless_asciidoc
    assert_includes Documark::Include.registered, 'asciidoc'
    assert_equal 'asciidoc', Documark::Include.lookup_by_ext('.adoc')
    assert_equal 'asciidoc', Documark::Include.lookup_by_ext('.asciidoc')
  end

  def test_plugin_registers_asciidoc_feature
    skip_unless_asciidoc
    assert Documark::Plugins.feature?('asciidoc'),
           "expected 'asciidoc' feature to be registered by the plugin"
    assert_equal 'asciidoc', Documark::Include.feature_for('asciidoc'),
                 "include-type 'asciidoc' should link back to feature 'asciidoc'"
  end

  def test_require_features_passes_when_asciidoc_loaded
    skip_unless_asciidoc
    Documark::Plugins.require_features!(['asciidoc'], source: 'test')
  end

  def test_include_asciidoc_auto_detects_by_extension
    skip_unless_asciidoc
    body = "Before\n\n@( include 'include_asciidoc.adoc' )\n\nAfter"
    result = Documark::TagProcessor.process(body, 'input_path' => File.join(FIXTURE_DIR, 'doc.dm'))
    assert_includes result, 'Asciidoc Section'
    assert_includes result, 'This paragraph comes from an AsciiDoc include.'
  end

  def test_include_asciidoc_with_explicit_type_token
    skip_unless_asciidoc
    body = "@( include 'include_asciidoc.adoc' asciidoc )"
    result = Documark::TagProcessor.process(body, 'input_path' => File.join(FIXTURE_DIR, 'doc.dm'))
    assert_includes result, 'Asciidoc Section'
  end

  def test_include_asciidoc_strips_all_classes_except_language
    skip_unless_asciidoc
    body = "@( include 'include_asciidoc.adoc' )"
    result = Documark::TagProcessor.process(body, 'input_path' => File.join(FIXTURE_DIR, 'doc.dm'))

    # AsciiDoctor emits classes like `paragraph`, `ulist`, `sect1`, etc.
    # None of those should survive.
    %w[paragraph ulist sect1 sectionbody listingblock].each do |klass|
      refute_match(/class="[^"]*\b#{klass}\b/, result, "expected `#{klass}` class to be stripped")
    end

    # The `language-ruby` class on a code block should be preserved.
    assert_match(/<code[^>]*class="language-ruby"/, result)
  end

  def test_unknown_include_type_raises
    skip_unless_asciidoc
    body = "@( include 'include_asciidoc.adoc' bogus )"
    error = assert_raises(StandardError) do
      Documark::TagProcessor.process(body, 'input_path' => File.join(FIXTURE_DIR, 'doc.dm'))
    end
    assert_match(/unknown @\( include \) type/, error.message)
  end

  # ─── @(asciidoc begin) block directive ────────────────────────────────────────

  def test_asciidoc_block_directive_links_to_asciidoc_feature
    skip_unless_asciidoc
    assert_equal 'asciidoc',
                 Documark::Directives.feature_for('asciidoc'),
                 "block directive 'asciidoc' should link back to feature 'asciidoc'"
    assert_equal :block, Documark::Directives.kind_for('asciidoc')
  end

  def test_asciidoc_block_renders_table
    skip_unless_asciidoc
    body = <<~DM
      @(asciidoc begin)
      |===
      | Col A | Col B

      | Cell A1
      | Cell B1
      |===
      @( end )
    DM
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<table>'
    assert_includes result, 'Col A'
    assert_includes result, 'Cell A1'
  end

  def test_asciidoc_block_strips_asciidoctor_table_classes
    skip_unless_asciidoc
    body = <<~DM
      @(asciidoc begin)
      |===
      | Header

      | Content
      |===
      @( end )
    DM
    result = Documark::TagProcessor.process(body)
    %w[tableblock frame-all grid-all halign-left valign-top stretch].each do |klass|
      refute_match(/class="[^"]*\b#{klass}\b/, result,
                   "expected Asciidoctor class `#{klass}` to be stripped from inline block")
    end
  end

  def test_asciidoc_block_renders_non_table_content
    skip_unless_asciidoc
    body = <<~DM
      @(asciidoc begin)
      term1:: Definition of term one.
      term2:: Definition of term two.
      @( end )
    DM
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'term1'
    assert_includes result, 'Definition of term one'
  end

end

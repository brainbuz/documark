# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/documark/tag_processor'

class TagProcessorTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # build_attrs
  # ---------------------------------------------------------------------------

  def test_build_attrs_returns_empty_for_blank_input
    assert_equal '', Documark::TagProcessor.build_attrs('')
    assert_equal '', Documark::TagProcessor.build_attrs(nil)
    assert_equal '', Documark::TagProcessor.build_attrs('   ')
  end

  def test_build_attrs_single_class
    assert_equal ' class="green"', Documark::TagProcessor.build_attrs('.green')
  end

  def test_build_attrs_multiple_classes
    assert_equal ' class="green larger"', Documark::TagProcessor.build_attrs('.green .larger')
  end

  def test_build_attrs_id
    assert_equal ' id="intro"', Documark::TagProcessor.build_attrs('#intro')
  end

  def test_build_attrs_class_and_id
    result = Documark::TagProcessor.build_attrs('.warning #note')
    assert_includes result, 'class="warning"'
    assert_includes result, 'id="note"'
  end

  def test_build_attrs_quoted_data_attribute
    result = Documark::TagProcessor.build_attrs('data-section="1"')
    assert_includes result, 'data-section="1"'
  end

  def test_build_attrs_unquoted_data_attribute
    result = Documark::TagProcessor.build_attrs('data-x=foo')
    assert_includes result, 'data-x="foo"'
  end

  def test_build_attrs_quoted_takes_precedence_over_unquoted
    result = Documark::TagProcessor.build_attrs('data-x="bar"')
    assert_includes result, 'data-x="bar"'
    refute_includes result, '"'*3
  end

  # ---------------------------------------------------------------------------
  # @{} single-block form
  # ---------------------------------------------------------------------------

  def test_block_tag_single_block_wraps_next_block_in_div
    body = "@{ .green }\nThis is a paragraph."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<div class="green">'
    assert_includes result, 'This is a paragraph.'
    assert_includes result, '</div>'
  end

  def test_block_tag_single_block_does_not_consume_following_blank_line_block
    body = "@{ .green }\nFirst block.\n\nSecond block."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<div class="green">'
    assert_includes result, 'First block.'
    assert_includes result, '</div>'
    assert_includes result, 'Second block.'
    # Second block should NOT be inside the div
    div_content = result[/<div[^>]*>(.*?)<\/div>/m, 1]
    refute_includes div_content.to_s, 'Second block.'
  end

  # ---------------------------------------------------------------------------
  # @{} section form
  # ---------------------------------------------------------------------------

  def test_block_tag_section_wraps_multiple_blocks
    body = "@{ .warning }\n\nFirst paragraph.\n\nSecond paragraph.\n\n@{}"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<div class="warning">'
    assert_includes result, 'First paragraph.'
    assert_includes result, 'Second paragraph.'
    assert_includes result, '</div>'
  end

  def test_block_tag_section_with_id_and_data
    body = "@{ .box #main data-level=\"2\" }\n\nContent.\n\n@{}"
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'class="box"'
    assert_includes result, 'id="main"'
    assert_includes result, 'data-level="2"'
    assert_includes result, '</div>'
  end

  # ---------------------------------------------------------------------------
  # @{} inline/span form
  # ---------------------------------------------------------------------------

  def test_inline_tag_unterminated_wraps_next_word
    body = "Text @{ .highlight } word more text."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<span class="highlight">word</span>'
    assert_includes result, 'more text.'
  end

  def test_inline_tag_with_explicit_close
    body = "Text @{ .highlight } a run of words @{} done."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<span class="highlight">a run of words</span>'
    assert_includes result, 'done.'
  end

  # ---------------------------------------------------------------------------
  # @[] single-block form
  # ---------------------------------------------------------------------------

  def test_semantic_tag_single_block_wraps_in_named_element
    body = "@[aside .callout]\nThis is an aside."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside class="callout">'
    assert_includes result, 'This is an aside.'
    assert_includes result, '</aside>'
  end

  def test_semantic_tag_single_block_no_classes
    body = "@[figure]\nAn image description."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<figure>'
    assert_includes result, 'An image description.'
    assert_includes result, '</figure>'
  end

  # ---------------------------------------------------------------------------
  # @[] section form
  # ---------------------------------------------------------------------------

  def test_semantic_tag_section_wraps_multiple_blocks
    body = "@[aside .note]\n\nFirst.\n\nSecond.\n\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside class="note">'
    assert_includes result, 'First.'
    assert_includes result, 'Second.'
    assert_includes result, '</aside>'
  end

  def test_semantic_tag_section_close_requires_matching_element
    # @[/article] should NOT close an @[aside] section
    body = "@[aside]\n\nContent.\n@[/article]\nMore.\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside>'
    assert_includes result, '</aside>'
    # The @[/article] line should appear in content (not consumed as close)
    assert_includes result, '@[/article]'
  end

  # ---------------------------------------------------------------------------
  # Pass-through: lines without tags are unchanged
  # ---------------------------------------------------------------------------

  def test_plain_markdown_is_unchanged
    body = "# Heading\n\nA paragraph.\n\n- item one\n- item two"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '# Heading'
    assert_includes result, 'A paragraph.'
    assert_includes result, '- item one'
  end

  # ---------------------------------------------------------------------------
  # Escaping: \@ suppresses tag processing
  # ---------------------------------------------------------------------------

  def test_escaped_block_tag_on_own_line_is_literal
    body = "\\@{ .green }\nThis paragraph is NOT wrapped."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<div'
    assert_includes result, '@{ .green }'
    assert_includes result, 'This paragraph is NOT wrapped.'
  end

  def test_escaped_block_tag_does_not_absorb_following_block
    body = "\\@{ .green }\nFirst.\n\nSecond."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<div'
    assert_includes result, '@{ .green }'
    assert_includes result, 'First.'
    assert_includes result, 'Second.'
  end

  def test_escaped_semantic_tag_on_own_line_is_literal
    body = "\\@[aside .note]\nThis is NOT an aside."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<aside'
    assert_includes result, '@[aside .note]'
    assert_includes result, 'This is NOT an aside.'
  end

  def test_escaped_semantic_close_is_literal
    body = "@[aside]\n\nContent.\n\n\\@[/aside]\n\nMore.\n\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside>'
    assert_includes result, '</aside>'
    assert_includes result, '@[/aside]'
  end

  def test_escaped_inline_tag_is_literal
    body = "Text \\@{ .highlight } word more text."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<span'
    assert_includes result, '@{ .highlight }'
    assert_includes result, 'word more text.'
  end

  def test_backslash_before_non_at_is_unchanged
    body = "A \\*backslash\\* before non-at passes through."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '\\*backslash\\*'
  end

  # ---------------------------------------------------------------------------
  # @<> inline element form
  # ---------------------------------------------------------------------------

  def test_inline_element_explicit_close
    body = "Text @<u> underlined text @</u> done."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<u>underlined text</u>'
    assert_includes result, 'done.'
  end

  def test_inline_element_unterminated_wraps_next_word
    body = "Text @<u> word more text."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<u>word</u>'
    assert_includes result, 'more text.'
  end

  def test_inline_element_with_class
    body = "Text @<mark .highlight> important @</mark> done."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<mark class="highlight">important</mark>'
    assert_includes result, 'done.'
  end

  def test_inline_element_with_id
    body = "See @<span #ref> this @</span> below."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<span id="ref">this</span>'
    assert_includes result, 'below.'
  end

  def test_escaped_inline_element_is_literal
    body = "Text \\@<u> word more text."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<u>word</u>'
    assert_includes result, '@<u>'
    assert_includes result, 'word more text.'
  end

  # ---------------------------------------------------------------------------
  # @(toc) directive
  # ---------------------------------------------------------------------------

  def test_toc_directive_emits_nav_wrapper_and_kramdown_marker
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<nav id="toc">'
    assert_includes result, '</nav>'
    assert_includes result, '* TOC'
    assert_includes result, '{:toc}'
  end

  def test_toc_directive_injects_default_depth_option
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '{::options toc_levels="1..3" /}'
  end

  def test_toc_directive_honors_layout_depth
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body, 'toc' => { 'depth' => 2 })
    assert_includes result, '{::options toc_levels="1..2" /}'
  end

  def test_toc_directive_uses_default_depth_when_partial_toc_block
    # toc block exists but only sets title; depth must fall back to default.
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body, 'toc' => { 'title' => 'Contents' })
    assert_includes result, '{::options toc_levels="1..3" /}'
  end

  def test_toc_directive_omits_title_when_partial_toc_block
    # toc block exists but only sets depth; title must remain unset.
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body, 'toc' => { 'depth' => 2 })
    refute_includes result, 'toc-title'
  end

  def test_toc_directive_works_with_empty_layout_hash
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body, {})
    assert_includes result, '{::options toc_levels="1..3" /}'
    refute_includes result, 'toc-title'
  end

  def test_toc_directive_works_with_nil_opts
    body = "@(toc)\n"
    # nil should be treated as "no opts at all" without raising
    result = Documark::TagProcessor.process(body, nil)
    assert_includes result, '{::options toc_levels="1..3" /}'
    refute_includes result, 'toc-title'
  end

  def test_toc_directive_emits_title_when_set
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body, 'toc' => { 'title' => 'Contents' })
    assert_includes result, '<h2 class="toc-title">Contents</h2>'
  end

  def test_toc_directive_omits_title_when_unset
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body)
    refute_includes result, 'toc-title'
  end

  def test_toc_directive_omits_title_when_blank
    body = "@(toc)\n"
    result = Documark::TagProcessor.process(body, 'toc' => { 'title' => '   ' })
    refute_includes result, 'toc-title'
  end

  def test_toc_directive_raises_on_second_occurrence
    body = "@(toc)\n\nIntro.\n\n@(toc)\n"
    error = assert_raises(StandardError) { Documark::TagProcessor.process(body) }
    assert_match(/multiple .*@\(toc\)/i, error.message)
  end

  def test_unknown_directive_raises
    body = "@(bogus)\n"
    error = assert_raises(StandardError) { Documark::TagProcessor.process(body) }
    assert_match(/unknown.*directive/i, error.message)
  end

  # ---------------------------------------------------------------------------
  # Self-describing placeholder format
  # ---------------------------------------------------------------------------

  def test_make_placeholder_wraps_html_in_comment
    ph = Documark::TagProcessor.make_placeholder('<div class="green">')
    assert_equal '<!--DMTAG:<div class="green">:DMTAG-->', ph
  end

  def test_make_placeholder_returns_nil_and_warns_on_double_dash
    result = nil
    _stdout, stderr = capture_io do
      result = Documark::TagProcessor.make_placeholder('<div data-x="--bad-->">')
    end
    assert_nil result
    assert_match(/ignoring tag/i, stderr)
    assert_match(/--/, stderr)
  end

  def test_invalid_data_attribute_drops_tag_keeps_content
    # Content inside the offending tag should still render; the wrapper
    # silently disappears (with a stderr warning) rather than aborting.
    body = "@[aside data-x=\"--bad-->\"]\n\nThe content survives.\n\n@[/aside]"
    result = nil
    _stdout, stderr = capture_io do
      result = Documark::TagProcessor.process(body)
    end
    refute_includes result, '<aside'
    assert_includes result, 'The content survives.'
    assert_match(/ignoring tag/i, stderr)
  end

  def test_postprocess_round_trips_self_describing_comment
    placeholder = Documark::TagProcessor.make_placeholder('<aside class="note">')
    surrounded  = "before #{placeholder} after"
    assert_equal 'before <aside class="note"> after', Documark::TagProcessor.postprocess(surrounded)
  end

  def test_postprocess_handles_multiple_placeholders
    open_ph  = Documark::TagProcessor.make_placeholder('<u>')
    close_ph = Documark::TagProcessor.make_placeholder('</u>')
    surrounded = "x #{open_ph}word#{close_ph} y"
    assert_equal 'x <u>word</u> y', Documark::TagProcessor.postprocess(surrounded)
  end

  # ---------------------------------------------------------------------------
  # Inline forms inside block forms (locks down the calling structure of
  # the block scanner -- block content lines must still pass through the
  # inline processor).
  # ---------------------------------------------------------------------------

  def test_inline_element_inside_semantic_block_section
    body = "@[aside]\n\nThis @<u>word@</u> works.\n\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside>'
    assert_includes result, '<u>word</u>'
    assert_includes result, '</aside>'
  end

  def test_inline_span_inside_block_div_section
    body = "@{ .green }\n\nA @{ .highlight } word @{} more text.\n\n@{}"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<div class="green">'
    assert_includes result, '<span class="highlight">word</span>'
    assert_includes result, '</div>'
  end
end

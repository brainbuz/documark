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

  # ---------------------------------------------------------------------------
  # @(# ...) full index directive and @# shorthand
  # ---------------------------------------------------------------------------

  def test_index_full_form_no_wrap_emits_empty_anchor
    body = "Some text @(# Battle of Lexington and Concord) and more."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-battle-of-lexington-and-concord-1"></a>'
    assert_includes result, 'Some text'
    assert_includes result, 'and more.'
  end

  def test_index_full_form_no_inner_space_still_works
    body = "Text @(#Battle of Lexington and Concord) more."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-battle-of-lexington-and-concord-1"></a>'
  end

  def test_index_full_form_does_not_wrap_following_word
    # The full form @(# term) always emits an empty anchor. Words after
    # the closing ) are plain prose, never wrapped. Authors who want a
    # different displayed word from the indexed term place the empty
    # anchor immediately before the prose word — that's enough for PDF
    # anchor resolution. (Wrap-with-explicit-term is deferred.)
    body = "The @(# Battle of Lexington and Concord) Lexington started it all."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-battle-of-lexington-and-concord-1"></a>'
    # "Lexington" stays as plain prose; not wrapped in any anchor.
    refute_match(/<a id="ix-battle-of-lexington-[^"]*">Lexington<\/a>/, result)
    assert_includes result, 'Lexington started it all.'
  end

  def test_index_shorthand_wraps_word_term_is_word
    body = "Text @# Lexington more text."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-lexington-1">Lexington</a>'
    assert_includes result, 'more text.'
  end

  def test_index_shorthand_no_space_still_works
    body = "Text @#Lexington more."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-lexington-1">Lexington</a>'
  end

  def test_index_counter_increments_per_entry
    body = "First @(# Foo) and second @(# Foo) again."
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'ix-foo-1'
    assert_includes result, 'ix-foo-2'
  end

  def test_index_counter_increments_across_full_and_shorthand
    body = "First @(# Alpha) and shorthand @# Beta done."
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'ix-alpha-1'
    assert_includes result, 'ix-beta-2'
  end

  def test_index_slug_normalizes_punctuation
    body = %(Text @(# AT&T's "Best") more.)
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'ix-at-t-s-best-1'
  end

  def test_index_slug_handles_unicode
    body = "Text @(# café) more."
    result = Documark::TagProcessor.process(body)
    # Non-[a-z0-9] chars become hyphens, then trimmed.
    assert_includes result, 'ix-caf-1'
  end

  def test_escaped_index_full_form_is_literal
    body = "Text \\@(# Foo) more text."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<a id='
    assert_includes result, '@(# Foo)'
  end

  def test_escaped_index_shorthand_is_literal
    body = "Text \\@# foo more text."
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<a id='
    assert_includes result, '@# foo'
  end

  def test_index_full_form_takes_precedence_over_shorthand
    # The full-form regex must run first so the @# inside @(#...) isn't
    # consumed by the shorthand regex below it.
    body = "Text @(# Foo) and more."
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-foo-1"></a>'
    # Shorthand should NOT have eaten part of the full form, indexing "Foo)".
    refute_match(/ix-foo[^"]*\)/, result)
  end

  def test_plain_text_with_no_markers_passes_through
    body = "Plain text with no index markers."
    result = Documark::TagProcessor.process(body)
    assert_equal "Plain text with no index markers.", result
  end

  def test_index_full_form_inside_block_section
    body = "@[aside]\n\nThis paragraph has @(# Foo) inside it.\n\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside>'
    assert_includes result, '<a id="ix-foo-1"></a>'
    assert_includes result, '</aside>'
  end

  def test_index_shorthand_inside_block_section
    body = "@[aside]\n\nThis paragraph has @# Lexington in it.\n\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<aside>'
    assert_includes result, '<a id="ix-lexington-1">Lexington</a>'
    assert_includes result, '</aside>'
  end

  def test_index_full_form_inside_block_does_not_wrap_word
    body = "@[aside]\n\nThe @(# Battle of Lexington and Concord) Lexington started.\n\n@[/aside]"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-battle-of-lexington-and-concord-1"></a>'
    refute_match(/<a id="ix-battle[^"]*">Lexington<\/a>/, result)
    assert_includes result, 'Lexington started.'
  end

  # ---------------------------------------------------------------------------
  # @(index) placement directive
  # ---------------------------------------------------------------------------

  def test_index_placement_emits_nav_and_dl_for_single_entry
    body = "Text @(# Foo) more.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<nav id="index">'
    assert_includes result, '<dl>'
    assert_includes result, '<dt>Foo</dt>'
    assert_includes result, '<a href="#ix-foo-1"></a>'
    assert_includes result, '</dd>'
    assert_includes result, '</dl>'
    assert_includes result, '</nav>'
  end

  def test_index_placement_groups_multiple_occurrences_under_one_term
    body = "First @(# Alpha) and @(# Alpha) again.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    # Only one <dt>Alpha</dt> despite two registrations.
    assert_equal 1, result.scan('<dt>Alpha</dt>').size
    # The single <dd> contains two anchor links, numbered 1 and 2.
    assert_match(/<dd[^>]*><a href="#ix-alpha-1"><\/a>, <a href="#ix-alpha-2"><\/a><\/dd>/, result)
  end

  def test_index_placement_sorts_terms_case_insensitively
    body = "@(# zebra) @(# apple) @(# Mango)\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    # Order in output should be apple, Mango, zebra (case-insensitive sort).
    apple_pos  = result.index('<dt>apple</dt>')
    mango_pos  = result.index('<dt>Mango</dt>')
    zebra_pos  = result.index('<dt>zebra</dt>')
    refute_nil apple_pos
    refute_nil mango_pos
    refute_nil zebra_pos
    assert apple_pos < mango_pos, "apple should come before Mango"
    assert mango_pos < zebra_pos, "Mango should come before zebra"
  end

  def test_index_placement_emits_title_when_set
    body = "Text @(# Foo).\n\n@(index)"
    result = Documark::TagProcessor.process(body, 'index' => { 'title' => 'Index' })
    assert_includes result, '<h2 class="index-title">Index</h2>'
  end

  def test_index_placement_omits_title_when_unset
    body = "Text @(# Foo).\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    refute_includes result, 'index-title'
    refute_includes result, '<h2'
  end

  def test_index_placement_omits_title_when_blank
    body = "Text @(# Foo).\n\n@(index)"
    result = Documark::TagProcessor.process(body, 'index' => { 'title' => '   ' })
    refute_includes result, 'index-title'
  end

  def test_index_placement_with_empty_registry_emits_nothing
    body = "Plain text with no index entries.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    refute_includes result, '<nav id="index"'
    refute_includes result, '<dl>'
  end

  def test_index_placement_raises_on_second_occurrence
    body = "@(# Foo).\n\n@(index)\n\nMore.\n\n@(index)"
    error = assert_raises(StandardError) { Documark::TagProcessor.process(body) }
    assert_match(/multiple .*@\(index\)/i, error.message)
  end

  def test_index_placement_appends_user_classes_to_nav
    body = "@(# Foo).\n\n@(index)"
    result = Documark::TagProcessor.process(body, 'index' => { 'classes' => { 'nav' => 'sidebar' } })
    assert_includes result, '<nav id="index" class="sidebar">'
  end

  def test_index_placement_appends_user_classes_to_title
    body = "@(# Foo).\n\n@(index)"
    opts = { 'index' => { 'title' => 'Index', 'classes' => { 'title' => 'fancy' } } }
    result = Documark::TagProcessor.process(body, opts)
    assert_includes result, '<h2 class="index-title fancy">Index</h2>'
  end

  def test_index_placement_appends_user_classes_to_dl_dt_dd
    body = "@(# Foo).\n\n@(index)"
    opts = {
      'index' => {
        'classes' => { 'dl' => 'columns-2', 'dt' => 'term', 'dd' => 'locs' }
      }
    }
    result = Documark::TagProcessor.process(body, opts)
    assert_includes result, '<dl class="columns-2">'
    assert_includes result, '<dt class="term">Foo</dt>'
    assert_includes result, '<dd class="locs">'
  end

  def test_index_placement_with_no_class_config_uses_defaults
    body = "@(# Foo).\n\n@(index)"
    result = Documark::TagProcessor.process(body, 'index' => {})
    # No class on nav, dl, dt, dd.
    assert_includes result, '<nav id="index">'
    assert_includes result, '<dl>'
    assert_includes result, '<dt>Foo</dt>'
    assert_includes result, '<dd>'
  end

  def test_index_placement_works_after_shorthand_entries
    body = "Text @# alpha and @# beta done.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<dt>alpha</dt>'
    assert_includes result, '<dt>beta</dt>'
  end

  # ---------------------------------------------------------------------------
  # Shorthand word boundary: \p{L}+ — letters only, anything else terminates
  # ---------------------------------------------------------------------------

  def test_shorthand_stops_at_period_in_prose
    body = "Text @# Documark. continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    # Wrapped word is letters-only; the period stays unwrapped in prose.
    assert_includes result, '<a id="ix-documark-1">Documark</a>. continues.'
    assert_includes result, '<dt>Documark</dt>'
  end

  def test_shorthand_stops_at_comma_in_prose
    body = "Text @# Documark, continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-documark-1">Documark</a>, continues.'
    assert_includes result, '<dt>Documark</dt>'
  end

  def test_shorthand_stops_at_punctuation_run
    body = "Text @# Wow!? continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-wow-1">Wow</a>!? continues.'
    assert_includes result, '<dt>Wow</dt>'
  end

  def test_shorthand_dedups_same_term_across_trailing_punct_variations
    # Documark, Documark., Documark; — all register as "Documark"
    # because punctuation terminates the word in every case.
    body = "@# Documark works. @# Documark, also works. @# Documark; again.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_equal 1, result.scan('<dt>Documark</dt>').size
    assert_match(/<dd[^>]*><a href="#ix-documark-1"><\/a>, <a href="#ix-documark-2"><\/a>, <a href="#ix-documark-3"><\/a><\/dd>/, result)
  end

  def test_shorthand_stops_at_hyphen
    # Hyphens are punctuation — they terminate. To index "Paul-Revere"
    # as one term, use the full form @(# Paul-Revere).
    body = "Text @# Paul-Revere ride continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-paul-1">Paul</a>-Revere'
    assert_includes result, '<dt>Paul</dt>'
  end

  def test_shorthand_stops_at_apostrophe
    body = "Text @# Asciidoctor's PDF theming.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, %(<a id="ix-asciidoctor-1">Asciidoctor</a>'s)
    assert_includes result, '<dt>Asciidoctor</dt>'
  end

  def test_shorthand_stops_at_digit
    # Digits terminate — to index "5G", "Web3", or similar, use full form.
    body = "Text @# Web3 continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-web-1">Web</a>3'
    assert_includes result, '<dt>Web</dt>'
  end

  def test_shorthand_does_not_match_when_no_letters_follow
    # @# !!! — punctuation only after the sigil, no letters. The regex
    # requires at least one letter, so nothing matches. The literal
    # source text passes through unchanged.
    body = "Text @# !!! continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'Text @# !!! continues.'
    refute_includes result, '<a id='
  end

  def test_shorthand_does_not_match_when_digits_follow
    body = "Text @# 5G continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'Text @# 5G continues.'
    refute_includes result, '<a id='
  end

  def test_shorthand_handles_accented_latin
    body = "Text @# café continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    # \p{L} matches the accented é, so the term includes it.
    assert_includes result, '<a id="ix-caf-1">café</a>'
    assert_includes result, '<dt>café</dt>'
  end

  def test_shorthand_handles_non_latin_script
    # Cyrillic — all letters under \p{L}.
    body = "Text @# Россия continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    # Slug strips to empty (no [a-z0-9]), ID falls back to ix-N.
    assert_includes result, '<a id="ix-1">Россия</a>'
    assert_includes result, '<dt>Россия</dt>'
  end

  def test_full_form_keeps_trailing_punctuation_inside_parens
    # @(# term.) keeps the period — punctuation between parens is the
    # author's explicit choice.
    body = "Text @(# Battle of Lexington and Concord.) continues.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<dt>Battle of Lexington and Concord.</dt>'
  end

  def test_full_form_supports_digits_and_punctuation_in_term
    body = "Text @(# 5G networks) details.\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<dt>5G networks</dt>'
  end

  # ---------------------------------------------------------------------------
  # @( include 'file' ) directive
  # ---------------------------------------------------------------------------

  FIXTURES = File.expand_path('fixtures', __dir__)

  def test_include_markdown_by_extension
    body = "@( include '#{FIXTURES}/include_markdown.md' )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '## Included Heading'
    assert_includes result, 'This is included markdown content.'
  end

  def test_include_html_by_extension
    body = "@( include '#{FIXTURES}/include_html.html' )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<section class="imported">Raw HTML block.</section>'
  end

  def test_include_text_by_extension_renders_as_code_fence
    body = "@( include '#{FIXTURES}/include_text.txt' )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '```'
    assert_includes result, 'plain text line one'
    assert_includes result, 'plain text line two'
  end

  def test_include_type_override_forces_markdown
    body = "@( include '#{FIXTURES}/include_text.txt' markdown )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'plain text line one'
    refute_includes result, '```'
  end

  def test_include_type_override_forces_html
    body = "@( include '#{FIXTURES}/include_markdown.md' html )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '## Included Heading'
    refute_includes result, '```'
  end

  def test_include_type_override_forces_text
    body = "@( include '#{FIXTURES}/include_markdown.md' text )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '```'
    assert_includes result, '## Included Heading'
  end

  def test_include_markdown_processes_tags_in_included_file
    body = "@( include '#{FIXTURES}/include_with_index.md' )\n\n@(index)"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<a id="ix-includedterm-1"></a>'
    assert_includes result, '<dt>IncludedTerm</dt>'
  end

  def test_include_nested_resolves_paths_relative_to_including_file
    body = "@( include '#{FIXTURES}/include_nested_parent.md' )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'Parent line before.'
    assert_includes result, '## Included Heading'
    assert_includes result, 'This is included markdown content.'
    assert_includes result, 'Parent line after.'
  end

  def test_include_surrounding_content_preserved
    body = "Before.\n\n@( include '#{FIXTURES}/include_markdown.md' )\n\nAfter."
    result = Documark::TagProcessor.process(body)
    assert_includes result, 'Before.'
    assert_includes result, '## Included Heading'
    assert_includes result, 'After.'
  end

  def test_include_missing_file_raises
    body = "@( include '/nonexistent/path/missing.md' )"
    error = assert_raises(StandardError) { Documark::TagProcessor.process(body) }
    assert_match(/include file not found/i, error.message)
  end

  def test_include_with_single_quotes
    body = "@( include '#{FIXTURES}/include_markdown.md' )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '## Included Heading'
  end

  def test_include_with_double_quotes
    body = %(@( include "#{FIXTURES}/include_markdown.md" ))
    result = Documark::TagProcessor.process(body)
    assert_includes result, '## Included Heading'
  end
end

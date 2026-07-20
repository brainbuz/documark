# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/documark/conditionals'

class ConditionalsTest < Minitest::Test
  C = Documark::Conditionals

  # ---------------------------------------------------------------------------
  # evaluate — bare truthy
  # ---------------------------------------------------------------------------

  def test_evaluate_truthy_string_value
    assert C.evaluate('name', { 'name' => 'John' })
  end

  def test_evaluate_truthy_boolean_true
    assert C.evaluate('flag', { 'flag' => true })
  end

  def test_evaluate_truthy_integer_zero
    assert C.evaluate('count', { 'count' => 0 })
  end

  def test_evaluate_truthy_string_zero
    assert C.evaluate('count', { 'count' => '0' })
  end

  def test_evaluate_truthy_array
    assert C.evaluate('list', { 'list' => [] })
    assert C.evaluate('list', { 'list' => [1, 2] })
  end

  def test_evaluate_truthy_hash
    assert C.evaluate('map', { 'map' => { 'a' => 1 } })
  end

  # ---------------------------------------------------------------------------
  # evaluate — bare falsy
  # ---------------------------------------------------------------------------

  def test_evaluate_falsy_missing_key
    refute C.evaluate('missing', {})
  end

  def test_evaluate_falsy_nil_value
    refute C.evaluate('name', { 'name' => nil })
  end

  def test_evaluate_falsy_false_value
    refute C.evaluate('flag', { 'flag' => false })
  end

  def test_evaluate_falsy_empty_string
    refute C.evaluate('name', { 'name' => '' })
  end

  def test_evaluate_falsy_whitespace_string
    refute C.evaluate('name', { 'name' => '   ' })
  end

  def test_evaluate_falsy_literal_false_lowercase
    refute C.evaluate('name', { 'name' => 'false' })
  end

  def test_evaluate_falsy_literal_false_uppercase
    refute C.evaluate('name', { 'name' => 'FALSE' })
  end

  # ---------------------------------------------------------------------------
  # evaluate — negation
  # ---------------------------------------------------------------------------

  def test_evaluate_negated_truthy_is_false
    refute C.evaluate('!name', { 'name' => 'John' })
  end

  def test_evaluate_negated_falsy_is_true
    assert C.evaluate('!name', { 'name' => '' })
    assert C.evaluate('!missing', {})
    assert C.evaluate('!flag', { 'flag' => false })
  end

  def test_evaluate_negated_with_whitespace
    refute C.evaluate('! name', { 'name' => 'x' })
  end

  # ---------------------------------------------------------------------------
  # evaluate — equality
  # ---------------------------------------------------------------------------

  def test_evaluate_equality_string_match
    assert C.evaluate('color=red', { 'color' => 'red' })
    refute C.evaluate('color=red', { 'color' => 'blue' })
  end

  def test_evaluate_equality_boolean_coercion
    assert C.evaluate('flag=true', { 'flag' => true })
    refute C.evaluate('flag=true', { 'flag' => false })
  end

  def test_evaluate_equality_integer_coercion
    assert C.evaluate('n=5', { 'n' => 5 })
    refute C.evaluate('n=5', { 'n' => 6 })
  end

  def test_evaluate_equality_float_coercion
    assert C.evaluate('n=5.0', { 'n' => 5.0 })
    refute C.evaluate('n=5.0', { 'n' => 5 })
  end

  def test_evaluate_equality_missing_key_is_false
    refute C.evaluate('color=red', {})
    refute C.evaluate('color=', {})
  end

  def test_evaluate_equality_empty_value_matches_nil
    assert C.evaluate('name=', { 'name' => nil })
  end

  def test_evaluate_equality_empty_value_matches_empty_string
    assert C.evaluate('name=', { 'name' => '' })
  end

  def test_evaluate_equality_value_side_stripped
    # VALUE is stripped after the first '='.
    assert C.evaluate('name=  x  ', { 'name' => 'x' })
  end

  def test_evaluate_equality_no_strip_on_data_side
    # The data side is compared via to_s with no strip, so trailing space
    # in the stored value prevents a match against the stripped VALUE.
    refute C.evaluate('name=x', { 'name' => 'x ' })
  end

  def test_evaluate_equality_after_first_equals
    assert C.evaluate('expr=a=b', { 'expr' => 'a=b' })
  end

  def test_evaluate_equality_single_quoted_value
    assert C.evaluate("greeting='hi there'", { 'greeting' => 'hi there' })
  end

  def test_evaluate_equality_double_quoted_value
    assert C.evaluate('greeting="hi there"', { 'greeting' => 'hi there' })
  end

  def test_evaluate_equality_quoted_empty_value
    assert C.evaluate('name=""', { 'name' => '' })
  end

  # ---------------------------------------------------------------------------
  # evaluate — malformed
  # ---------------------------------------------------------------------------

  def test_evaluate_malformed_empty
    assert_raises(StandardError) { C.evaluate('', {}) }
    assert_raises(StandardError) { C.evaluate('   ', {}) }
    assert_raises(StandardError) { C.evaluate(nil, {}) }
  end

  def test_evaluate_malformed_negation_with_equality
    error = assert_raises(StandardError) { C.evaluate('!k=v', {}) }
    assert_match(/malformed/, error.message)
  end

  def test_evaluate_malformed_bad_name
    assert_raises(StandardError) { C.evaluate('1abc', {}) }
    assert_raises(StandardError) { C.evaluate('1abc=x', {}) }
    assert_raises(StandardError) { C.evaluate('!1abc', {}) }
  end

  # ---------------------------------------------------------------------------
  # split_branches
  # ---------------------------------------------------------------------------

  def test_split_branches_no_else
    true_lines, else_lines = C.split_branches(%w[a b c])
    assert_equal %w[a b c], true_lines
    assert_equal [], else_lines
  end

  def test_split_branches_simple_else
    lines = ['a', '@( else )', 'b']
    true_lines, else_lines = C.split_branches(lines)
    assert_equal ['a'], true_lines
    assert_equal ['b'], else_lines
  end

  def test_split_branches_nested_if_else_does_not_split_outer
    lines = [
      'top',
      '@( if inner begin )',
      'inner-true',
      '@( else )',
      'inner-false',
      '@( end )',
      '@( else )',
      'outer-else'
    ]
    true_lines, else_lines = C.split_branches(lines)
    assert_equal ['top', '@( if inner begin )', 'inner-true', '@( else )', 'inner-false', '@( end )'], true_lines
    assert_equal ['outer-else'], else_lines
  end

  def test_split_branches_multiple_depth_zero_else_raises
    lines = ['a', '@( else )', 'b', '@( else )', 'c']
    error = assert_raises(StandardError) { C.split_branches(lines) }
    assert_match(/multiple @\( else \)/, error.message)
  end

  # ---------------------------------------------------------------------------
  # resolve
  # ---------------------------------------------------------------------------

  def test_resolve_true_keeps_branch
    text = "before\n@( if show begin )\nkept\n@( end )\nafter"
    assert_equal "before\nkept\nafter", C.resolve(text, { 'show' => true })
  end

  def test_resolve_false_drops_to_else
    text = "@( if show begin )\nkept\n@( else )\nelse-content\n@( end )"
    assert_equal 'else-content', C.resolve(text, { 'show' => false })
  end

  def test_resolve_false_no_else_removes_block
    text = "before\n@( if show begin )\nkept\n@( end )\nafter"
    assert_equal "before\nafter", C.resolve(text, { 'show' => false })
  end

  def test_resolve_nested_if_outer_true_inner_false
    text = <<~DOC.chomp
      @( if outer begin )
      outer-top
      @( if inner begin )
      inner-true
      @( else )
      inner-false
      @( end )
      outer-bottom
      @( end )
    DOC
    result = C.resolve(text, { 'outer' => true, 'inner' => false })
    assert_equal "outer-top\ninner-false\nouter-bottom", result
  end

  def test_resolve_nested_if_outer_false
    text = <<~DOC.chomp
      @( if outer begin )
      @( if inner begin )
      inner
      @( end )
      @( else )
      outer-else
      @( end )
    DOC
    result = C.resolve(text, { 'outer' => false, 'inner' => true })
    assert_equal 'outer-else', result
  end

  def test_resolve_foreign_block_passes_through_untouched
    text = <<~DOC.chomp
      before
      @( asciidoc begin )
      raw content
      @( else )
      not an else here
      @( end )
      after
    DOC
    # No data key referenced; the foreign block must be copied verbatim
    # including the inner @( else )-looking line and its own opener/end.
    assert_equal text, C.resolve(text, {})
  end

  def test_resolve_unterminated_if_warns_and_treats_rest_as_content
    text = "before\n@( if show begin )\nrest of doc"
    out, err = capture_io do
      result = C.resolve(text, { 'show' => true })
      assert_equal "before\nrest of doc", result
    end
    assert_match(/was never closed/, out + err)
  end

  def test_resolve_orphan_else_raises
    text = "before\n@( else )\nafter"
    error = assert_raises(StandardError) { C.resolve(text, {}) }
    assert_match(/unexpected @\( else \)/, error.message)
  end

  def test_resolve_preserves_trailing_newline
    text = "line\n"
    assert_equal "line\n", C.resolve(text, {})
  end
end

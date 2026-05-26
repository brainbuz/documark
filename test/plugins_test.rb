# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/documark/plugins'

class PluginsTest < Minitest::Test
  # ─── Feature name validation ────────────────────────────────────────────────

  def test_register_feature_accepts_valid_names
    Documark::Plugins.register_feature('test-valid-1', plugin: 'test')
    assert Documark::Plugins.feature?('test-valid-1')
  ensure
    Documark::Plugins.features.delete('test-valid-1')
  end

  def test_register_feature_rejects_invalid_names
    %w[Bad UPPER 1numeric -leadhyphen has_underscore has.dot has\ space].each do |bad|
      assert_raises(ArgumentError) do
        Documark::Plugins.register_feature(bad)
      end
    end
  end

  # ─── Built-in features ──────────────────────────────────────────────────────

  def test_builtin_features_are_registered
    %w[markdown html text pdf epub toc index include].each do |name|
      assert Documark::Plugins.feature?(name), "expected built-in feature '#{name}' to be registered"
    end
  end

  def test_builtin_targets_listed_in_registry
    %w[html pdf markdown text epub].each do |name|
      assert_includes Documark::Targets.registered, name
      assert_equal name, Documark::Targets.feature_for(name),
                   "target '#{name}' should link to feature '#{name}'"
    end
  end

  # ─── require_features! ──────────────────────────────────────────────────────

  def test_require_features_passes_when_all_present
    Documark::Plugins.require_features!(%w[markdown html], source: 'test')
  end

  def test_require_features_noop_on_empty_or_nil
    Documark::Plugins.require_features!(nil, source: 'test')
    Documark::Plugins.require_features!([], source: 'test')
  end

  def test_require_features_raises_with_missing_name_and_source
    error = assert_raises(StandardError) do
      Documark::Plugins.require_features!(['nonexistent-feature'], source: '/path/to/doc.dm')
    end
    assert_match(/'nonexistent-feature'/, error.message)
    assert_match(%r{/path/to/doc\.dm}, error.message)
  end

  def test_require_features_lists_all_missing
    error = assert_raises(StandardError) do
      Documark::Plugins.require_features!(%w[markdown foo bar baz], source: 'doc')
    end
    %w[foo bar baz].each { |m| assert_match(/'#{m}'/, error.message) }
    refute_match(/'markdown'/, error.message)
  end

  # ─── Directives registry ────────────────────────────────────────────────────

  def test_directives_register_and_lookup
    Documark::Plugins.register_feature('test-feat', plugin: 'test')
    Documark::Directives.register('test-bd', feature: 'test-feat', kind: :block) do |_a, c, _ctx|
      { content: c, mode: :placeholder }
    end
    assert_includes Documark::Directives.registered, 'test-bd'
    assert_equal 'test-feat', Documark::Directives.feature_for('test-bd')
    assert_equal :block, Documark::Directives.kind_for('test-bd')
    refute_nil Documark::Directives.lookup('test-bd')
  ensure
    Documark::Directives.instance_variable_get(:@handlers).delete('test-bd')
    Documark::Plugins.instance_variable_get(:@features).delete('test-feat')
  end

  def test_directives_lookup_returns_nil_for_unknown
    assert_nil Documark::Directives.lookup('does-not-exist')
    assert_nil Documark::Directives.feature_for('does-not-exist')
    assert_nil Documark::Directives.kind_for('does-not-exist')
  end

  def test_directives_register_requires_block
    assert_raises(ArgumentError) do
      Documark::Directives.register('test-noblock')
    end
  end

  def test_directives_register_rejects_invalid_name
    assert_raises(ArgumentError) do
      Documark::Directives.register('Bad-Name') { |_a, _c, _ctx| nil }
    end
  end

  def test_directives_register_rejects_invalid_kind
    assert_raises(ArgumentError) do
      Documark::Directives.register('test-badkind', kind: :bogus) { |_a, _c, _ctx| nil }
    end
  end

  def test_directives_register_rejects_unknown_feature
    assert_raises(ArgumentError) do
      Documark::Directives.register('test-nofeat', feature: 'no-such-feature') { |_a, _c, _ctx| nil }
    end
  end
end

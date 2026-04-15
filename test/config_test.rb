# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative '../lib/documark/config'

class DocumarkConfigTest < Minitest::Test
  def setup
    @previous_debug = Documark::Config.send(:debug?)
    Documark::Config.send(:debug=, true)
  end

  def teardown
    Documark::Config.send(:debug=, @previous_debug)
  end

  def test_read_config_parses_mapping_and_expands_default_layout
    Dir.mktmpdir('documark-config-test') do |tmpdir|
      config_path = File.join(tmpdir, 'documark.conf')
      File.write(config_path, <<~CONF)
        ---
        default_layout: ./layouts/default.dml
        template_folder: ~/Templates/
        ---
      CONF

      parsed = Documark::Config.read_config(config_path)

      assert_equal File.expand_path('./layouts/default.dml'), parsed['default_layout']
      assert_equal '~/Templates/', parsed['template_folder']
    end
  end

  def test_read_config_requires_mapping
    Dir.mktmpdir('documark-config-test') do |tmpdir|
      config_path = File.join(tmpdir, 'bad.conf')
      File.write(config_path, <<~CONF)
        ---
        - item
        - item
        ---
      CONF

      error = assert_raises(StandardError) do
        Documark::Config.read_config(config_path)
      end

      assert_equal 'Config file must be a mapping', error.message
    end
  end

  def test_executable_on_path_detects_ruby
    assert_equal true, Documark::Config.executable_on_path?('ruby')
  end
end

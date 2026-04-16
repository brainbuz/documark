# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'rbconfig'
require_relative 'test_helper'

class DocumarkCliTest < Minitest::Test
  def run_cli(*args, stdin_data: nil)
    exe = File.expand_path('../bin/documark', __dir__)
    preload = File.expand_path('support/simplecov_subprocess.rb', __dir__)

    env = {}
    if ENV['COVERAGE'] == '1'
      existing_rubyopt = ENV['RUBYOPT'].to_s
      env['RUBYOPT'] = [existing_rubyopt, "-r#{preload}"].reject(&:empty?).join(' ')
      env['COVERAGE'] = '1'
    end

    Open3.capture3(env, RbConfig.ruby, exe, *args, stdin_data: stdin_data)
  end

  def fixture_path(name)
    File.expand_path("fixtures/#{name}", __dir__)
  end

  def test_exits_with_error_when_action_is_missing
    _stdout, stderr, status = run_cli

    refute status.success?
    assert_includes stderr, 'Missing action. Usage: documark <action> @switches.'
  end

  def test_exits_with_error_when_required_process_options_are_missing
    _stdout, stderr, status = run_cli('process')

    refute status.success?
    assert_includes stderr, 'Missing required option for process action: --input'
  end

  def test_exits_with_error_for_invalid_target
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      output_path = File.join(tmpdir, 'out.invalid')

      _stdout, stderr, status = run_cli(
        'process',
        '--input', fixture_path('fmerrormissing.dm'),
        '--output', output_path,
        '--target', 'invalid'
      )

      refute status.success?
      assert_includes stderr, "Invalid target 'invalid'. Supported targets:"
    end
  end

  def test_html_target_writes_html_output
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      output_path = File.join(tmpdir, 'out.html')

      _stdout, stderr, status = run_cli(
        'process',
        '--input', File.expand_path('../doc/examples/simple.dm', __dir__),
        '--output', output_path,
        '--target', 'html'
      )

      assert status.success?, stderr
      html = File.read(output_path)
      assert_includes html, '<!doctype html>'
      assert_includes html, '<h1 id="documark-makes-word-processors-obsolete">DocuMark Makes Word Processors Obsolete!</h1>'
      assert_includes html, '<title>A Simple DocuMark Document</title>'
    end
  end

  def test_markdown_target_strips_kramdown_attribute_lists
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input_path = File.join(tmpdir, 'with-attrs.dm')
      output_path = File.join(tmpdir, 'out.md')

      File.write(input_path, <<~DOC)
        !! documark document
        !! data
        title: "Attr Test"
        !! end

        # Heading
        {: .big}

        Paragraph with an inline attribute{: .highlighted}
      DOC

      _stdout, stderr, status = run_cli(
        'process',
        '--input', input_path,
        '--output', output_path,
        '--target', 'markdown'
      )

      assert status.success?, stderr
      output = File.read(output_path)
      refute_includes output, '{: .big}'
      refute_includes output, '{: .highlighted}'
      assert_includes output, '# Heading'
      assert_includes output, 'Paragraph with an inline attribute'
    end
  end

  def test_warns_and_defaults_title_when_data_section_is_missing
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      output_path = File.join(tmpdir, 'out.html')

      _stdout, stderr, status = run_cli(
        'process',
        '--input', fixture_path('fmerrormissing.dm'),
        '--output', output_path,
        '--target', 'html'
      )

      assert status.success?, stderr
      assert_includes stderr, 'No data section found; defaulting title to fmerrormissing.dm'
      html = File.read(output_path)
      assert_includes html, '<title>fmerrormissing.dm</title>'
    end
  end

  def test_fails_when_data_section_is_unterminated
    _stdout, stderr, status = run_cli(
      'process',
      '--input', fixture_path('fmerrorsimple.dm'),
      '--output', '/tmp/out.html',
      '--target', 'html'
    )

    refute status.success?
    assert_includes stderr, 'Unterminated data block'
  end
end

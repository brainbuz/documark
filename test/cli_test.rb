# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'rbconfig'
require 'fileutils'
require_relative 'test_helper'
require_relative '../lib/documark/container'

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
    assert_includes stderr, 'Missing action. Supported actions: process, pack, unpack, config_new, template_new'
    assert_includes stderr, "Run 'documark --help' for usage."
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
      assert_match(/required feature\(s\) not available:.*'invalid'/, stderr)
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

  def test_markdown_target_strips_documark_attribute_lists
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input_path = File.join(tmpdir, 'with-attrs.dm')
      output_path = File.join(tmpdir, 'out.md')

      File.write(input_path, <<~DOC)
        !! documark document
        !! data
        title: "Attr Test"
        !! end

        @{ .big }
        # Heading

        Paragraph with an inline attribute@{ .highlighted }
      DOC

      _stdout, stderr, status = run_cli(
        'process',
        '--input', input_path,
        '--output', output_path,
        '--target', 'markdown'
      )

      assert status.success?, stderr
      output = File.read(output_path)
      refute_includes output, '{: big}'
      refute_includes output, '{: highlighted}'
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

  def test_html_target_with_define_selects_draft_branch
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input_path = File.join(tmpdir, 'conditional.dm')
      output_path = File.join(tmpdir, 'out.html')

      File.write(input_path, <<~DOC)
        !! documark document
        !! data
        title: "Conditional Test"
        !! end
        # Heading

        @( if draft begin )
        DRAFT TEXT
        @( else )
        FINAL TEXT
        @( end )
      DOC

      _stdout, stderr, status = run_cli(
        'process',
        '--input', input_path,
        '--output', output_path,
        '--target', 'html',
        '--define', 'draft'
      )

      assert status.success?, stderr
      html = File.read(output_path)
      assert_includes html, 'DRAFT TEXT'
      refute_includes html, 'FINAL TEXT'
    end
  end

  def test_html_target_without_define_selects_else_branch
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input_path = File.join(tmpdir, 'conditional.dm')
      output_path = File.join(tmpdir, 'out.html')

      File.write(input_path, <<~DOC)
        !! documark document
        !! data
        title: "Conditional Test"
        !! end
        # Heading

        @( if draft begin )
        DRAFT TEXT
        @( else )
        FINAL TEXT
        @( end )
      DOC

      _stdout, stderr, status = run_cli(
        'process',
        '--input', input_path,
        '--output', output_path,
        '--target', 'html'
      )

      assert status.success?, stderr
      html = File.read(output_path)
      refute_includes html, 'DRAFT TEXT'
      assert_includes html, 'FINAL TEXT'
    end
  end

  def test_markdown_target_with_define_selects_branch_and_strips_directives
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input_path = File.join(tmpdir, 'conditional.dm')
      output_path = File.join(tmpdir, 'out.md')

      File.write(input_path, <<~DOC)
        !! documark document
        !! data
        title: "Conditional Test"
        !! end
        # Heading

        @( if draft begin )
        DRAFT TEXT
        @( else )
        FINAL TEXT
        @( end )
      DOC

      _stdout, stderr, status = run_cli(
        'process',
        '--input', input_path,
        '--output', output_path,
        '--target', 'markdown',
        '--define', 'draft'
      )

      assert status.success?, stderr
      output = File.read(output_path)
      assert_includes output, 'DRAFT TEXT'
      refute_includes output, 'FINAL TEXT'
      refute_includes output, '@('
    end
  end

  def test_define_overrides_document_data
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input_path = File.join(tmpdir, 'conditional.dm')
      output_path = File.join(tmpdir, 'out.html')

      File.write(input_path, <<~DOC)
        !! documark document
        !! data
        title: "Conditional Test"
        audience: public
        !! end
        # Heading

        @( if audience=internal begin )
        INTERNAL TEXT
        @( else )
        PUBLIC TEXT
        @( end )
      DOC

      _stdout, stderr, status = run_cli(
        'process',
        '--input', input_path,
        '--output', output_path,
        '--target', 'html',
        '--define', 'audience=internal'
      )

      assert status.success?, stderr
      html = File.read(output_path)
      assert_includes html, 'INTERNAL TEXT'
      refute_includes html, 'PUBLIC TEXT'
    end
  end

  # ── pack / unpack ────────────────────────────────────────────────────────

  def container_fixture_document
    <<~DOC
      !! documark document
      !! data
      title: "Pack Test"
      !! end
      !! layout
      ---
      stylesheets:
        - style.css
      ---
      !! end

      # Heading

      @( include 'chapter.md' )

      ![logo](img/logo.png)
    DOC
  end

  def write_container_fixture(dir)
    File.write(File.join(dir, 'doc.dm'), container_fixture_document)
    File.write(File.join(dir, 'style.css'), "body { color: black; }\n")
    File.write(File.join(dir, 'chapter.md'), "Included chapter text.\n")
    FileUtils.mkdir_p(File.join(dir, 'img'))
    File.binwrite(File.join(dir, 'img/logo.png'), Random.bytes(64))
    File.join(dir, 'doc.dm')
  end

  def test_pack_action_produces_container_with_assets_section
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input = write_container_fixture(tmpdir)
      output = File.join(tmpdir, 'doc.dmc')

      _stdout, stderr, status = run_cli('pack', '--input', input, '--output', output)

      assert status.success?, stderr
      packed = File.read(output)
      assert_match(/^!! assets\n/, packed)
      assert packed.end_with?("!! end\n"), 'container should end with !! end'
    end
  end

  def test_unpack_action_restores_document_and_assets_byte_identical
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input = write_container_fixture(tmpdir)
      container = File.join(tmpdir, 'doc.dmc')

      _pack_stdout, pack_stderr, pack_status = run_cli('pack', '--input', input, '--output', container)
      assert pack_status.success?, pack_stderr

      Dir.mktmpdir('documark-cli-test-dest') do |dest|
        _stdout, stderr, status = run_cli('unpack', '--input', container, '--output', dest)

        assert status.success?, stderr

        restored_doc = File.join(dest, 'doc.dm')
        assert File.file?(restored_doc), 'restored document should use the .dm extension'
        assert_equal File.read(input), File.read(restored_doc)

        %w[style.css chapter.md img/logo.png].each do |rel|
          restored = File.join(dest, rel)
          assert File.file?(restored), "expected #{rel} to be restored"
          assert_equal File.binread(File.join(tmpdir, rel)), File.binread(restored),
                       "#{rel} should be byte-identical after round trip"
        end
      end
    end
  end

  def test_pack_action_fails_when_input_is_already_a_container
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input = write_container_fixture(tmpdir)
      container = File.join(tmpdir, 'doc.dmc')

      _pack_stdout, pack_stderr, pack_status = run_cli('pack', '--input', input, '--output', container)
      assert pack_status.success?, pack_stderr

      _stdout, stderr, status = run_cli(
        'pack', '--input', container, '--output', File.join(tmpdir, 'again.dmc')
      )

      refute status.success?
      assert_match(/already a container/, stderr)
    end
  end

  def test_unpack_action_fails_when_input_is_not_a_container
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      input = write_container_fixture(tmpdir)

      Dir.mktmpdir('documark-cli-test-dest') do |dest|
        _stdout, stderr, status = run_cli('unpack', '--input', input, '--output', dest)

        refute status.success?
        assert_match(/not a container/, stderr)
      end
    end
  end

  def test_pack_action_exits_with_error_when_required_options_are_missing
    _stdout, stderr, status = run_cli('pack')

    refute status.success?
    assert_includes stderr, 'Missing required option for pack action: --input'
  end

  def test_unpack_action_exits_with_error_when_required_options_are_missing
    _stdout, stderr, status = run_cli('unpack')

    refute status.success?
    assert_includes stderr, 'Missing required option for unpack action: --input'
  end

  # ── container render integration ─────────────────────────────────────────

  def weasyprint_available?
    system('weasyprint --version', out: File::NULL, err: File::NULL)
  end

  # Pack a fixture tree and move the resulting container into a fresh, empty
  # directory so rendering has no access to the original assets — the only
  # way includes/images/css can resolve is via extraction of the packed
  # !! assets section.
  def pack_and_isolate(tmpdir, dest)
    input = write_container_fixture(tmpdir)
    container = File.join(tmpdir, 'doc.dmc')

    _stdout, stderr, status = run_cli('pack', '--input', input, '--output', container)
    assert status.success?, stderr

    FileUtils.mkdir_p(dest)
    moved = File.join(dest, 'doc.dmc')
    FileUtils.mv(container, moved)
    moved
  end

  def test_html_target_on_container_extracts_assets_beside_output
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      Dir.mktmpdir('documark-cli-render') do |dest|
        container = pack_and_isolate(tmpdir, dest)
        output = File.join(dest, 'out.html')

        _stdout, stderr, status = run_cli(
          'process', '--input', container, '--output', output, '--target', 'html'
        )

        assert status.success?, stderr
        html = File.read(output)
        assert_includes html, 'Included chapter text.'
        assert_includes html, 'img/logo.png'

        assert File.file?(File.join(dest, 'style.css')), 'style.css should be extracted beside output'
        assert File.file?(File.join(dest, 'chapter.md')), 'chapter.md should be extracted beside output'
        assert File.file?(File.join(dest, 'img/logo.png')), 'img/logo.png should be extracted beside output'
      end
    end
  end

  def test_markdown_target_on_container_does_not_extract_assets
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      Dir.mktmpdir('documark-cli-render') do |dest|
        container = pack_and_isolate(tmpdir, dest)
        output = File.join(dest, 'out.md')

        _stdout, stderr, status = run_cli(
          'process', '--input', container, '--output', output, '--target', 'markdown'
        )

        assert status.success?, stderr
        assert File.file?(output), 'markdown output should be written'
        refute File.exist?(File.join(dest, 'style.css')), 'markdown target must not extract assets'
        refute File.exist?(File.join(dest, 'img/logo.png')), 'markdown target must not extract assets'
      end
    end
  end

  def test_pdf_target_on_container_extracts_to_tempdir_and_cleans_up
    skip 'weasyprint not available' unless weasyprint_available?

    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      Dir.mktmpdir('documark-cli-render') do |dest|
        container = pack_and_isolate(tmpdir, dest)
        output = File.join(dest, 'out.pdf')

        _stdout, stderr, status = run_cli(
          'process', '--input', container, '--output', output, '--target', 'pdf'
        )

        assert status.success?, stderr
        assert File.file?(output), 'PDF output should be written'
        assert File.binread(output).start_with?('%PDF'), 'output should be a PDF'

        # PDF assets extract into a temp dir, never beside the output.
        refute File.exist?(File.join(dest, 'style.css')), 'PDF target must not extract beside output'
        refute File.exist?(File.join(dest, 'img/logo.png')), 'PDF target must not extract beside output'
      end
    end
  end

  # ── stationery (.dms) ────────────────────────────────────────────────────

  # Write a stationery source tree — a layout (.dml) whose stylesheet pulls a
  # font in via url() — and return the .dml path.
  def write_stationery_source(dir, css_name: 'paper.css', css_body: nil)
    File.write(File.join(dir, 'paper.dml'), <<~DML)
      !! documark layout
      !! layout
      ---
      stylesheets:
        - #{css_name}
      ---
      !! end
    DML
    FileUtils.mkdir_p(File.join(dir, 'fonts'))
    File.binwrite(File.join(dir, 'fonts/serif.woff2'), Random.bytes(48))
    File.write(File.join(dir, css_name),
               css_body || "@font-face { font-family: S; src: url('fonts/serif.woff2'); }\nbody { color: navy; }\n")
    File.join(dir, 'paper.dml')
  end

  def plain_document
    <<~DOC
      !! documark document
      !! data
      title: "Plain"
      !! end

      # Hello
    DOC
  end

  def test_pack_layout_file_into_stationery_with_font_via_url
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      dml = write_stationery_source(tmpdir)
      dms = File.join(tmpdir, 'paper.dms')

      _stdout, stderr, status = run_cli('pack', '--input', dml, '--output', dms)

      assert status.success?, stderr
      packed = File.read(dms)
      assert_match(/^!! assets\n/, packed)

      # The stationery's assets section must carry both the stylesheet and the
      # font it pulls in via url().
      sections = Documark::Parser.split_documark_sections(packed)
      refute_nil sections['assets']

      Dir.mktmpdir('documark-cli-dms-decode') do |dest|
        Documark::Container.decode_assets(sections['assets'], dest)
        assert File.file?(File.join(dest, 'paper.css')), 'stationery should carry its stylesheet'
        assert File.file?(File.join(dest, 'fonts/serif.woff2')), 'stationery should carry the url()-referenced font'
      end
    end
  end

  def test_process_with_stationery_extracts_assets_beside_output
    Dir.mktmpdir('documark-cli-test') do |tmpdir|
      dml = write_stationery_source(tmpdir)
      dms = File.join(tmpdir, 'paper.dms')
      _o, pack_err, pack_status = run_cli('pack', '--input', dml, '--output', dms)
      assert pack_status.success?, pack_err

      Dir.mktmpdir('documark-cli-render') do |dest|
        # Move the self-contained stationery away from its source assets so the
        # only way its css/font can appear beside the output is extraction.
        moved_dms = File.join(dest, 'paper.dms')
        FileUtils.mv(dms, moved_dms)

        input = File.join(dest, 'plain.dm')
        File.write(input, plain_document)
        output = File.join(dest, 'out.html')

        _stdout, stderr, status = run_cli(
          'process', '--input', input, '--output', output, '--target', 'html', '--layout', moved_dms
        )

        assert status.success?, stderr
        html = File.read(output)
        assert_includes html, 'paper.css'

        assert File.file?(File.join(dest, 'paper.css')), 'stationery stylesheet should be extracted beside output'
        assert File.file?(File.join(dest, 'fonts/serif.woff2')), 'stationery font should be extracted beside output'
      end
    end
  end

  def test_process_document_assets_win_over_stationery_on_collision
    Dir.mktmpdir('documark-cli-test') do |src|
      # Stationery provides its own style.css.
      write_stationery_source(src, css_body: "/* STATIONERY */\nbody { color: navy; }\n")
      dms = File.join(src, 'paper.dms')
      _o, pack_err, pack_status = run_cli('pack', '--input', File.join(src, 'paper.dml'), '--output', dms)
      assert pack_status.success?, pack_err

      Dir.mktmpdir('documark-cli-render') do |dest|
        moved_dms = File.join(dest, 'paper.dms')
        FileUtils.mv(dms, moved_dms)

        # Build a document container that carries its OWN style.css (document wins).
        File.write(File.join(dest, 'style.css'), "/* DOCUMENT */\nbody { color: crimson; }\n")
        encoded = Documark::Container.encode_assets(['style.css'], dest)
        input = File.join(dest, 'doc.dm')
        File.write(input, "#{plain_document}!! assets\n#{encoded}!! end\n")
        # Remove the loose style.css so only extraction can recreate it.
        FileUtils.rm(File.join(dest, 'style.css'))

        output = File.join(dest, 'out.html')
        _stdout, stderr, status = run_cli(
          'process', '--input', input, '--output', output, '--target', 'html', '--layout', moved_dms
        )

        assert status.success?, stderr
        on_disk = File.read(File.join(dest, 'style.css'))
        assert_includes on_disk, 'DOCUMENT', 'document style.css must win on collision'
        refute_includes on_disk, 'STATIONERY', 'stationery style.css must not be the surviving copy'
      end
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

# frozen_string_literal: true

require 'tmpdir'
require 'stringio'
require 'zlib'
require 'rubygems/package'
require_relative 'test_helper'
require_relative '../lib/documark/container'

class DocumarkContainerTest < Minitest::Test
  # ── valid_asset_path? ───────────────────────────────────────────────────────

  def test_valid_asset_path_accepts_safe_relative_paths
    %w[a.css img/logo.png deep/a/b/c.txt].each do |good|
      assert Documark::Container.valid_asset_path?(good), "expected #{good.inspect} to be valid"
    end
  end

  def test_valid_asset_path_rejects_unsafe_paths
    ['/etc/passwd', '../x', 'a/../b', './a', 'a//b', '', "a\\b", "a\0b"].each do |bad|
      refute Documark::Container.valid_asset_path?(bad), "expected #{bad.inspect} to be rejected"
    end
  end

  # ── encode/decode round-trip ────────────────────────────────────────────────

  def test_encode_decode_round_trip_is_byte_identical
    Dir.mktmpdir('documark-container') do |src|
      File.write(File.join(src, 'readme.txt'), "hello\nworld\n")
      File.binwrite(File.join(src, 'blob.bin'), Random.bytes(512))
      FileUtils.mkdir_p(File.join(src, 'nested/deep'))
      File.binwrite(File.join(src, 'nested/deep/data.dat'), Random.bytes(300))

      relpaths = ['readme.txt', 'blob.bin', 'nested/deep/data.dat']
      encoded = Documark::Container.encode_assets(relpaths, src)

      assert_match(/\A[A-Za-z0-9+\/=\n]+\z/, encoded, 'encoded output should be pure base64 + newlines')

      Dir.mktmpdir('documark-container-dest') do |dest|
        Documark::Container.decode_assets(encoded, dest)

        relpaths.each do |rel|
          assert_equal File.binread(File.join(src, rel)),
                       File.binread(File.join(dest, rel)),
                       "#{rel} should decode byte-identically"
        end
      end
    end
  end

  def test_encode_rejects_unsafe_relpath
    Dir.mktmpdir('documark-container') do |src|
      assert_raises(StandardError) do
        Documark::Container.encode_assets(['../escape.txt'], src)
      end
    end
  end

  # ── decode defenses ─────────────────────────────────────────────────────────

  # Build a gzipped tar directly so we can smuggle a hostile entry name past
  # the encode-side validation and prove decode rejects it.
  def gzip_tar
    tar_io = StringIO.new
    Gem::Package::TarWriter.new(tar_io) { |tar| yield tar }
    gz_io = StringIO.new
    gz = Zlib::GzipWriter.new(gz_io)
    gz.write(tar_io.string)
    gz.finish
    [gz_io.string].pack('m')
  end

  def test_decode_rejects_path_traversal
    encoded = gzip_tar { |tar| tar.add_file('../evil.txt', 0o644) { |io| io.write('pwned') } }

    Dir.mktmpdir('documark-container-dest') do |dest|
      error = assert_raises(StandardError) do
        Documark::Container.decode_assets(encoded, dest)
      end
      assert_match(/unsafe path/, error.message)
      refute File.exist?(File.join(File.dirname(dest), 'evil.txt')),
             'traversal entry must never be written outside dest_dir'
    end
  end

  def test_decode_rejects_symlink_entry
    encoded = gzip_tar { |tar| tar.add_symlink('link', 'target', 0o644) }

    Dir.mktmpdir('documark-container-dest') do |dest|
      error = assert_raises(StandardError) do
        Documark::Container.decode_assets(encoded, dest)
      end
      assert_match(/non-file entry/, error.message)
      refute File.symlink?(File.join(dest, 'link'))
    end
  end

  # ── discover_assets ─────────────────────────────────────────────────────────

  def test_discover_assets_finds_local_refs_and_skips_urls_and_missing
    Dir.mktmpdir('documark-container') do |dir|
      File.write(File.join(dir, 'chapter.md'), '# chapter')
      File.write(File.join(dir, 'notes.txt'), 'notes')
      FileUtils.mkdir_p(File.join(dir, 'img'))
      File.write(File.join(dir, 'img/logo.png'), 'png')
      FileUtils.mkdir_p(File.join(dir, 'fonts'))
      File.write(File.join(dir, 'fonts/a.woff2'), 'font')
      File.write(File.join(dir, 'style.css'), 'body { background: url(../img/bg.png); }')
      # img/bg.png is intentionally never created.

      sections = {
        'body' => "@( include 'chapter.md' )\n@( include notes.txt text )\n![x](img/logo.png)\n"
      }
      layout = {
        'stylesheets' => ['style.css', 'https://cdn.example/x.css'],
        'style' => '@font-face { src: url("fonts/a.woff2?v=3"); }'
      }

      result = nil
      _out, err = capture_io do
        result = Documark::Container.discover_assets(sections, layout, dir)
      end

      assert_equal ['chapter.md', 'fonts/a.woff2', 'img/logo.png', 'notes.txt', 'style.css'], result
      assert_match(/bg\.png/, err, 'the escaping/missing bg.png ref should be warned about')
    end
  end

  def test_discover_assets_layout_mode_with_nil_body
    Dir.mktmpdir('documark-container') do |dir|
      File.write(File.join(dir, 'paper.css'), "body { background: url('img/bg.png'); }\n")
      FileUtils.mkdir_p(File.join(dir, 'img'))
      File.write(File.join(dir, 'img/bg.png'), 'png')
      FileUtils.mkdir_p(File.join(dir, 'fonts'))
      File.write(File.join(dir, 'fonts/serif.woff2'), 'font')

      # A stationery/layout has no body of its own — nil, not "".
      sections = { 'body' => nil }
      layout = {
        'stylesheets' => ['paper.css', 'https://cdn.example/x.css'],
        'style' => "@font-face { src: url('fonts/serif.woff2'); }"
      }

      result = nil
      _out, _err = capture_io do
        result = Documark::Container.discover_assets(sections, layout, dir)
      end

      # stylesheet, the url() in style, and the css-in-css url() all resolve;
      # a nil body contributes nothing and raises nothing.
      assert_equal ['fonts/serif.woff2', 'img/bg.png', 'paper.css'], result
    end
  end

  # ── pack_file / unpack_file ─────────────────────────────────────────────────

  def sample_document
    <<~DOC
      !! documark document
      !! data
      title: Packed
      !! end

      # Heading
      ![logo](img/logo.png)
    DOC
  end

  def test_pack_file_builds_container_and_preserves_text_verbatim
    Dir.mktmpdir('documark-container') do |dir|
      input = File.join(dir, 'doc.dm')
      File.write(input, sample_document)
      FileUtils.mkdir_p(File.join(dir, 'img'))
      File.binwrite(File.join(dir, 'img/logo.png'), Random.bytes(64))

      output = File.join(dir, 'doc.dmc')
      Documark::Container.pack_file(input, output)

      packed = File.read(output)
      above_assets = packed.split(/^!! assets\n/, 2).first
      assert_equal sample_document, above_assets, 'original text must be preserved verbatim above !! assets'
      assert_match(/^!! assets\n/, packed)
      assert_match(/^!! end\n\z/, packed)

      # The container must re-parse and expose a non-nil assets section.
      sections = Documark::Parser.split_documark_sections(packed)
      refute_nil sections['assets']
    end
  end

  def test_pack_file_refuses_to_double_pack
    Dir.mktmpdir('documark-container') do |dir|
      input = File.join(dir, 'doc.dm')
      File.write(input, sample_document)
      FileUtils.mkdir_p(File.join(dir, 'img'))
      File.binwrite(File.join(dir, 'img/logo.png'), Random.bytes(16))

      output = File.join(dir, 'doc.dmc')
      Documark::Container.pack_file(input, output)

      error = assert_raises(StandardError) do
        Documark::Container.pack_file(output, File.join(dir, 'again.dmc'))
      end
      assert_match(/already a container/, error.message)
    end
  end

  def test_unpack_file_round_trips_document_and_assets
    Dir.mktmpdir('documark-container') do |dir|
      input = File.join(dir, 'doc.dm')
      File.write(input, sample_document)
      FileUtils.mkdir_p(File.join(dir, 'img'))
      logo = Random.bytes(128)
      File.binwrite(File.join(dir, 'img/logo.png'), logo)

      container = File.join(dir, 'doc.dmc')
      Documark::Container.pack_file(input, container)

      Dir.mktmpdir('documark-container-out') do |dest|
        Documark::Container.unpack_file(container, dest)

        restored_doc = File.join(dest, 'doc.dm')
        assert File.file?(restored_doc), 'document should be written with a .dm extension'
        assert_equal sample_document, File.read(restored_doc)

        restored_logo = File.join(dest, 'img/logo.png')
        assert File.file?(restored_logo), 'asset tree should be recreated'
        assert_equal logo, File.binread(restored_logo)
      end
    end
  end
end

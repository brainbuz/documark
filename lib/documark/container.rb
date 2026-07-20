# frozen_string_literal: true

require 'rubygems/package'
require 'zlib'
require 'stringio'
require 'fileutils'
require 'pathname'
require_relative 'runtime'
require_relative 'parser'
require_relative 'include'

module Documark
  # Container packing/unpacking.
  #
  # A Documark "container" is an ordinary document with one extra section
  # appended at the very end:
  #
  #   !! assets
  #   <base64 of a gzipped POSIX tar>
  #   !! end
  #
  # The tar holds the document's supporting files (css, images, includes)
  # so a document plus its assets travels as a single, still-readable file.
  # Text sections stay plain; only the assets are archived.
  #
  # Path handling is deliberately strict: every relative path packed or
  # unpacked must pass valid_asset_path?, which is the security boundary
  # against path-traversal and absolute-path writes.
  module Container
    module_function
    extend Documark::Runtime

    # ── Path validation (security boundary) ──────────────────────────────────

    # A safe asset path is relative, /-separated, with no traversal, no empty
    # segments, no NUL, and no backslashes.
    def valid_asset_path?(path)
      return false unless path.is_a?(String)
      return false if path.empty?
      return false if path.include?("\0")
      return false if path.include?("\\")
      return false if path.start_with?('/')

      # Keep trailing empty segments so "a//b" and "a/" are rejected.
      segments = path.split('/', -1)
      return false if segments.empty?

      segments.all? { |seg| !seg.empty? && seg != '.' && seg != '..' }
    end

    # ── Encode / decode ───────────────────────────────────────────────────────

    # Pack relpaths (all relative to base_dir) into base64(gzip(tar)).
    def encode_assets(relpaths, base_dir)
      tar_io = StringIO.new
      Gem::Package::TarWriter.new(tar_io) do |tar|
        relpaths.each do |relpath|
          raise StandardError, "documark: invalid asset path: #{relpath.inspect}" unless valid_asset_path?(relpath)

          data = File.binread(File.join(base_dir, relpath))
          tar.add_file(relpath, 0o644) { |io| io.write(data) }
        end
      end
      tar_io.rewind

      gz_io = StringIO.new
      gz = Zlib::GzipWriter.new(gz_io)
      gz.write(tar_io.string)
      gz.finish

      # pack('m') is the base64 encoding Base64.encode64 uses internally: 60-char
      # lines with a trailing newline. Using it directly avoids depending on the
      # base64 gem, which is no longer a Ruby default gem.
      [gz_io.string].pack('m')
    end

    # Unpack a (possibly line-wrapped) base64 assets archive into dest_dir.
    # Never writes outside dest_dir; rejects any unsafe or non-file entry.
    def decode_assets(base64_string, dest_dir)
      raw = base64_string.to_s.gsub(/\s+/, '').unpack1('m')
      tar_bytes = Zlib::GzipReader.new(StringIO.new(raw)).read

      Gem::Package::TarReader.new(StringIO.new(tar_bytes)) do |tar|
        tar.each do |entry|
          next if entry.directory?

          name = entry.full_name
          raise StandardError, "documark: unsafe path in assets archive: #{name}" unless valid_asset_path?(name)
          raise StandardError, "documark: non-file entry in assets archive: #{name}" unless entry.file?

          dest = File.join(dest_dir, name)
          FileUtils.mkdir_p(File.dirname(dest))
          File.binwrite(dest, entry.read)
        end
      end
    end

    # ── Asset discovery ───────────────────────────────────────────────────────

    URL_RE           = /url\(\s*['"]?([^'")]+)['"]?\s*\)/i
    IMAGE_RE         = /!\[[^\]]*\]\(\s*([^)\s]+)/
    INCLUDE_RE       = /@\(\s*include\s+([^)]*)\)/
    SCHEME_RE        = %r{\A[a-z][a-z0-9+.-]*:}i

    # Discover every local supporting file referenced by a document (or layout).
    #
    #   sections — hash from Parser.split_documark_sections (body may be nil)
    #   layout   — parsed layout hash or nil
    #   base_dir — directory the document lives in; all paths resolve under it
    #
    # Returns a sorted, unique array of base_dir-relative paths that exist and
    # pass valid_asset_path?. URLs, data:, mailto:, fragment-only and absolute
    # refs are skipped; missing or unsafe files are warned about and skipped.
    def discover_assets(sections, layout, base_dir)
      base_dir = File.expand_path(base_dir)
      found = {}

      body = sections['body']
      if body
        body.scan(INCLUDE_RE) do |(args)|
          m = args.strip.match(Documark::Include::ARG_RE)
          add_ref(m[1] || m[2] || m[3], base_dir, from_dir: base_dir, into: found) if m
        end
        body.scan(IMAGE_RE) { |(ref)| add_ref(ref, base_dir, from_dir: base_dir, into: found) }
      end

      if layout
        Array(layout['stylesheets']).each { |ref| add_ref(ref, base_dir, from_dir: base_dir, into: found) }
        layout['style'].to_s.scan(URL_RE) { |(ref)| add_ref(ref, base_dir, from_dir: base_dir, into: found) }
      end

      # One recursion level: scan discovered .css files for their own url() refs,
      # resolved relative to each css file's own directory.
      found.keys.each do |rel|
        next unless rel.downcase.end_with?('.css')

        css_abs = File.join(base_dir, rel)
        next unless File.file?(css_abs)

        css_dir = File.dirname(css_abs)
        File.read(css_abs).scan(URL_RE) { |(ref)| add_ref(ref, base_dir, from_dir: css_dir, into: found) }
      end

      found.keys.sort
    end

    # Resolve a single reference relative to from_dir, re-relativize it to
    # base_dir, and record it if it is a safe, existing local file.
    def add_ref(ref, base_dir, from_dir:, into:)
      ref = ref.to_s.strip
      return if ref.empty?
      return if ref.match?(SCHEME_RE)   # http:, https:, data:, mailto:, ...
      return if ref.start_with?('#')    # fragment-only
      return if ref.start_with?('/')    # absolute path

      # Strip any query string / fragment (e.g. font.woff2?v=1#frag).
      ref = ref.sub(/[?#].*\z/, '')
      return if ref.empty?

      abs = File.expand_path(ref, from_dir)
      rel = Pathname.new(abs).relative_path_from(Pathname.new(base_dir)).to_s

      unless valid_asset_path?(rel)
        warn "documark: skipping unsafe asset reference: #{ref}"
        return
      end

      unless File.file?(File.join(base_dir, rel))
        warn "documark: skipping missing asset: #{rel}"
        return
      end

      into[rel] = true
    end

    # ── File-level pack / unpack ──────────────────────────────────────────────

    # Read a document, discover its assets, and write a container to
    # output_path: the original content verbatim followed by an !! assets
    # section. Refuses to double-pack an existing container.
    def pack_file(input_path, output_path)
      content  = File.read(input_path)
      sections = Parser.split_documark_sections(content)

      unless sections['assets'].nil?
        raise StandardError, "documark: #{input_path} is already a container — unpack first"
      end

      layout   = sections['layout'] ? Parser.parse_layout_section(sections['layout']) : nil
      base_dir = File.dirname(File.expand_path(input_path))
      relpaths = discover_assets(sections, layout, base_dir)

      warn "documark: no assets discovered in #{input_path}; writing empty container" if relpaths.empty?

      encoded = encode_assets(relpaths, base_dir)
      body    = content.end_with?("\n") ? content : "#{content}\n"

      File.write(output_path, "#{body}!! assets\n#{encoded}!! end\n")
    end

    # Read a container, write its document (without the assets section) and
    # unpack its asset tree into dest_dir. Refuses a non-container.
    def unpack_file(input_path, dest_dir)
      content  = File.read(input_path)
      sections = Parser.split_documark_sections(content)

      if sections['assets'].nil?
        raise StandardError, "documark: #{input_path} has no !! assets section — not a container"
      end

      FileUtils.mkdir_p(dest_dir)

      # Reconstruct the document: everything up to the `!! assets` line.
      lines       = content.lines
      assets_line = lines.find_index do |line|
        header = Parser.parse_header(line)
        header && header['context'] == 'assets'
      end
      document = lines[0...assets_line].join

      type    = sections['header_directive'] && sections['header_directive']['type']
      ext     = type == 'layout' ? '.dml' : '.dm'
      outname = File.basename(input_path, File.extname(input_path)) + ext
      File.write(File.join(dest_dir, outname), document)

      decode_assets(sections['assets'], dest_dir)
    end
  end
end

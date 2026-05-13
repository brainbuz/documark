# frozen_string_literal: true

module Documark
  module TagProcessor
    # ── Block/semantic/directive tag patterns ──────────────────────────────────
    # Matches a @{ ... } line that is the entire (stripped) line
    BLOCK_TAG_RE      = /\A@\{([^}]*)\}\z/
    # Matches a @[element attrs] line that is the entire (stripped) line
    SEMANTIC_TAG_RE   = /\A@\[([a-zA-Z][a-zA-Z0-9_-]*)([^\]]*)\]\z/
    # Matches a @[/element] closing line
    SEMANTIC_CLOSE_RE = /\A@\[\/([a-zA-Z][a-zA-Z0-9_-]*)\]\z/
    # Matches a @(name) Documark directive line
    DIRECTIVE_RE      = /\A@\(([a-z][a-z0-9-]*)\s*\)\z/
    # Matches @( include 'file' ) or @( include "file" ) with optional type.
    # m[1]=path, m[2]=type (markdown|html|text) or nil.
    INCLUDE_RE        = /\A@\(\s*include\s+['"]([^'"]+)['"]\s*(markdown|html|text)?\s*\)\z/
    INCLUDE_MD_EXTS   = %w[.md .markdown].freeze

    # ── Index patterns ─────────────────────────────────────────────────────────
    # Matches the full @(# term) index directive. m[1]=term phrase.
    # Always emits an empty anchor; never wraps. Run BEFORE
    # INDEX_SHORTHAND_RE so the @# opener of a full form isn't consumed
    # by the shorthand regex.
    INDEX_FULL_RE      = /@\(#\s*(.+?)\s*\)/
    # Matches the @# shorthand: @# word. The "word" is one or more
    # Unicode letter characters (\p{L}) — accented Latin and non-Latin
    # scripts are all treated as letters. Anything that is NOT a letter
    # (digits, punctuation, emoji, symbols, whitespace) terminates the
    # word. Authors who need digits, punctuation, or symbols inside an
    # index term must use the full form @(# term).
    INDEX_SHORTHAND_RE = /@#\s*(\p{L}+)/

    # ── Placeholder, escaping, defaults ────────────────────────────────────────
    # Finds self-describing placeholders in post-processed HTML.
    # The HTML to be restored is encoded directly inside the comment between
    # the :DMTAG markers, eliminating the need for a side-table registry.
    PLACEHOLDER_RE    = /<!--DMTAG:(.*?):DMTAG-->/m
    # Sentinel used internally to protect \@ escape sequences during inline processing
    ESCAPE_SENTINEL   = "\x00DMAT\x00"

    DEFAULT_TOC_DEPTH = 3

    # ── Public API ─────────────────────────────────────────────────────────────

    module_function

    # Phase 1: replace @{} and @[] directives with self-describing HTML
    # comment placeholders. Returns the transformed body string. Markdown
    # content is left untouched so Kramdown processes it normally.
    #
    # opts may contain:
    #   "toc"        => { "depth" => Integer (default 3), "title" => String|nil }
    #   "input_path" => String  — absolute path to the source document; used to
    #                             resolve relative @( include ) paths.
    def preprocess(body, opts = {})
      pp = Preprocessor.new(body, opts || {})
      result = pp.run
      # Surface emission flags to the caller via the shared opts hash so
      # downstream renderers (e.g. PDF post-processing) can react to the
      # presence of @(toc) / @(index) without re-parsing the body.
      if opts.is_a?(Hash)
        opts['toc_emitted']   = pp.instance_variable_get(:@toc_emitted)
        opts['index_emitted'] = pp.instance_variable_get(:@index_emitted)
      end
      result
    end

    # Phase 2: substitute placeholders emitted by preprocess with the HTML
    # encoded inside each placeholder's comment body.
    def postprocess(html)
      html.gsub(PLACEHOLDER_RE) { Regexp.last_match(1) }
    end

    # Convenience method: preprocess + postprocess without Kramdown in between.
    # Used directly by unit tests; real rendering goes through render_html.rb.
    def process(body, opts = {})
      postprocess(preprocess(body, opts || {}))
    end

    # Wrap an HTML fragment in a self-describing comment placeholder.
    #
    # Returns the placeholder string on success, or nil if the fragment
    # cannot be safely encoded. Currently the only rejection rule is the
    # presence of '--' (forbidden inside HTML comments). A nil return is
    # the caller's signal to fall back to passing the original source
    # line through as literal text. We warn but do not raise: a single
    # malformed attribute should not abort an entire document.
    def make_placeholder(html)
      if html.include?('--')
        warn "documark: ignoring tag with invalid '--' in attribute value: #{html.inspect}"
        return nil
      end

      "<!--DMTAG:#{html}:DMTAG-->"
    end

    # Parse @{} / @[] attribute string into an HTML attribute string.
    # Supports: .classname  #id  data-key="value"  data-key=value
    def build_attrs(str)
      return "" if str.nil? || str.strip.empty?

      classes    = []
      id         = nil
      data_attrs = {}

      str.scan(/\.([a-zA-Z][a-zA-Z0-9_-]*)/) { |m| classes << m[0] }
      str.scan(/#([a-zA-Z][a-zA-Z0-9_-]*)/)  { |m| id = m[0] }

      # Quoted data attributes first
      str.scan(/(data-[a-zA-Z][a-zA-Z0-9_-]*)="([^"]*)"/) { |k, v| data_attrs[k] = v }
      # Unquoted data attributes (||= so quoted value takes precedence)
      str.scan(/(data-[a-zA-Z][a-zA-Z0-9_-]*)=(\S+)/) do |k, v|
        data_attrs[k] ||= v.delete('"')
      end

      parts = []
      parts << %( class="#{classes.join(' ')}") unless classes.empty?
      parts << %( id="#{id}")                    if id
      data_attrs.each { |k, v| parts << %( #{k}="#{v}") }
      parts.join
    end

    # ── DirectiveMixin ─────────────────────────────────────────────────────────
    # Handles all @() directive forms: @(toc), @(index), @( include ),
    # and inline @(# term) / @# index registration. Mixed into Preprocessor
    # so all methods have transparent access to Preprocessor instance variables
    # (@out, @opts, @base_path, @toc_emitted, @index_emitted, @index_entries,
    # @index_counter) via self.
    module DirectiveMixin
      # Dispatch a @(name) directive to its expansion handler.
      def _emit_directive(name)
        case name
        when 'toc'
          _emit_toc
        when 'index'
          _emit_index
        else
          raise StandardError, "Unknown Documark directive: @(#{name})"
        end
      end

      # Expand @( include 'path' [type] ) by reading the file and splicing its
      # preprocessed content into @out. The included file's own @() directives
      # are processed because we recurse through a new Preprocessor whose
      # state (toc_emitted, index_entries, etc.) is shared via the parent.
      #
      # type is one of 'markdown', 'html', 'text', or nil (auto-detect by ext).
      # html  → raw content injected as a self-describing placeholder block.
      # text  → content emitted as a fenced code block so Kramdown escapes it.
      # markdown (or auto-detected .md/.markdown) → lines spliced in and
      #          walked by the parent preprocessor in the same pass.
      def _emit_include(rel_path, type_override = nil)
        abs_path = File.expand_path(rel_path, @base_path)
        content  = File.read(abs_path)

        ext  = File.extname(abs_path).downcase
        type = type_override || (INCLUDE_MD_EXTS.include?(ext) ? 'markdown' : ext == '.html' ? 'html' : 'text')

        case type
        when 'html'
          @out << _placeholder(content.strip)
        when 'text'
          @out << "```"
          @out.concat(content.lines(chomp: true))
          @out << "```"
        else
          # markdown: run a child Preprocessor scoped to the included file's
          # directory so its own @( include ) directives resolve correctly.
          # Share accumulated index state so entries register in the parent.
          included_base = File.dirname(abs_path)
          child = Preprocessor.new(content, @opts, base_path: included_base)
          child.instance_variable_set(:@index_entries, @index_entries)
          child.instance_variable_set(:@index_counter, @index_counter)
          child.instance_variable_set(:@toc_emitted,   @toc_emitted)
          child.instance_variable_set(:@index_emitted, @index_emitted)
          child.run
          # Pull back scalar mutations; arrays are shared by reference already.
          @index_counter = child.instance_variable_get(:@index_counter)
          @toc_emitted   = child.instance_variable_get(:@toc_emitted)
          @index_emitted = child.instance_variable_get(:@index_emitted)
          @out.concat(child.instance_variable_get(:@out))
        end
      rescue Errno::ENOENT
        raise StandardError, "documark: include file not found: #{abs_path}"
      end

      # Expand @(toc) into:
      #   <nav id="toc">                       (placeholder, opaque to Kramdown)
      #     <h2 class="toc-title">{title}</h2> (placeholder, only if title set)
      #     * TOC                              (Kramdown TOC marker; emits <ul id="markdown-toc">)
      #     {:toc}
      #   </nav>                               (placeholder)
      #
      # The depth (h1..hN) is controlled by the layout's toc.depth setting.
      # We honor it by injecting Kramdown's document option once at the top
      # of the output. Only one @(toc) per document is permitted; a second
      # occurrence is a hard error.
      def _emit_toc
        raise StandardError, "Multiple @(toc) directives are not supported" if @toc_emitted

        toc_opts = @opts.is_a?(Hash) ? (@opts['toc'] || {}) : {}
        depth    = (toc_opts['depth'] || DEFAULT_TOC_DEPTH).to_i
        title    = toc_opts['title']

        # Kramdown reads toc_levels as a document-level option. Inject it at
        # the very top of the output so it applies before the {:toc} marker.
        @out.unshift(%({::options toc_levels="1..#{depth}" /}), "")

        @out << _placeholder(%(<nav id="toc">))
        @out << _placeholder(%(<h2 class="toc-title">#{title}</h2>)) if title && !title.to_s.strip.empty?
        @out << ""
        @out << "* TOC"
        @out << "{:toc}"
        @out << ""
        @out << _placeholder("</nav>")

        @toc_emitted = true
      end

      # Expand @(index) into a sorted list of registered index entries.
      # Output structure:
      #   <nav id="index" class="...">
      #     <h2 class="index-title ...">{title}</h2>   (only if title set)
      #     <dl class="...">
      #       <dt class="...">{term}</dt>
      #       <dd class="..."><a href="#ix-...">1</a>, <a href="#ix-...">2</a></dd>
      #       ... (sorted alphabetically, case-insensitive, by term)
      #     </dl>
      #   </nav>
      #
      # If no entries are registered, emit nothing (silent skip).
      # Only one @(index) per document; a second occurrence is a hard error.
      # Class augmentation is configured via layout's index.classes.{nav,
      # title, dl, dt, dd} keys; user-supplied classes are appended to the
      # built-in ones.
      def _emit_index
        raise StandardError, "Multiple @(index) directives are not supported" if @index_emitted

        @index_emitted = true
        return if @index_entries.empty?

        idx_opts = @opts.is_a?(Hash) ? (@opts['index'] || {}) : {}
        title    = idx_opts['title']
        classes  = idx_opts['classes'] || {}

        nav_class   = _join_classes(nil,           classes['nav'])
        title_class = _join_classes('index-title', classes['title'])
        dl_class    = _join_classes(nil,           classes['dl'])
        dt_class    = _join_classes(nil,           classes['dt'])
        dd_class    = _join_classes(nil,           classes['dd'])

        @out << _placeholder(%(<nav id="index"#{_class_attr(nav_class)}>))
        @out << _placeholder(%(<h2#{_class_attr(title_class)}>#{title}</h2>)) if title && !title.to_s.strip.empty?
        @out << _placeholder(%(<dl#{_class_attr(dl_class)}>))

        # Group entries by term, then sort case-insensitively. Within a
        # term, preserve registration order (which corresponds to document
        # order — first occurrence first).
        grouped = @index_entries.group_by { |e| e[:term] }
                                .sort_by   { |term, _| term.downcase }

        grouped.each_with_index do |(term, entries), _|
          @out << _placeholder(%(<dt#{_class_attr(dt_class)}>#{term}</dt>))
          links = entries.map do |entry|
            %(<a href="##{entry[:id]}"></a>)
          end.join(", ")
          @out << _placeholder(%(<dd#{_class_attr(dd_class)}>#{links}</dd>))
        end

        @out << _placeholder("</dl>")
        @out << _placeholder("</nav>")
      end

      # Register an index entry and return the anchor placeholder HTML.
      # The anchor wraps `wrapped_text` if non-nil; otherwise the anchor
      # is empty. ID format: ix-<slug>-<global-counter>. Counter increments
      # on every entry so duplicate terms get unique IDs.
      def _emit_index_entry(term, wrapped_text = nil)
        @index_counter += 1
        slug = _index_slug(term)
        # When the term has no alphanumeric characters at all (e.g. "!!!"),
        # the slug is empty. Drop the slug segment from the ID so we don't
        # produce "ix--N" (the doubled hyphen would be rejected by the
        # placeholder validator since '--' is illegal inside HTML comments).
        id = slug.empty? ? "ix-#{@index_counter}" : "ix-#{slug}-#{@index_counter}"
        @index_entries << { term: term, id: id }
        _placeholder(%(<a id="#{id}">#{wrapped_text}</a>))
      end

      # Build a slug from an index term: lowercase, runs of non-alphanumeric
      # collapsed to single hyphens, trim leading/trailing hyphens.
      def _index_slug(term)
        term.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
      end

      # Join a built-in class name with a user-supplied class string.
      # Either may be nil/empty; result is nil if both are blank.
      def _join_classes(default, user)
        parts = []
        parts << default if default && !default.empty?
        parts << user.to_s.strip unless user.nil? || user.to_s.strip.empty?
        parts.empty? ? nil : parts.join(" ")
      end

      # Render a class="..." attribute when class is non-nil; otherwise "".
      def _class_attr(class_value)
        class_value ? %( class="#{class_value}") : ""
      end
    end

    # ── Preprocessor ───────────────────────────────────────────────────────────
    # Internal: walks the body line-by-line, replacing @{} and @[] directives
    # with self-describing HTML comment placeholders.
    #
    # Method-naming convention: methods prefixed with _ are internal helpers
    # not intended for external use. They aren't marked private because
    # nothing about calling them from outside would corrupt state, and the
    # _ prefix is sufficient signal to readers.
    class Preprocessor
      include DirectiveMixin

      def initialize(body, opts = {}, base_path: nil)
        @lines          = body.lines(chomp: true)
        @out            = []
        @opts           = opts
        @toc_emitted    = false
        @index_emitted  = false
        @index_entries  = []
        @index_counter  = 0
        # Base directory for resolving relative @( include ) paths.
        # Falls back to opts["input_path"] if not given directly (used by
        # recursive calls to carry the including file's directory).
        input_path = opts["input_path"]
        @base_path = base_path || (input_path ? File.dirname(File.expand_path(input_path)) : Dir.pwd)
      end

      # Scan a block-level construct starting at @lines[start_index] (which
      # is the opener line). Decides section-mode vs single-block by whether
      # the line right after the opener is blank. Emits open and close
      # placeholders around the content lines, calling _inline on each
      # content line so inline forms inside the block still get processed.
      # Returns the new index (one past the matched close, or end-of-input).
      def _scan_block(start_index:, open_html:, close_html:, close_detector:)
        open_ph  = _placeholder(open_html)
        close_ph = _placeholder(close_html)

        section_mode = @lines[start_index + 1].nil? || @lines[start_index + 1].strip.empty?
        i = start_index + 1

        @out << open_ph
        @out << ""

        if section_mode
          # Skip blank lines between opener and content.
          i += 1 while i < @lines.length && @lines[i].strip.empty?
          while i < @lines.length
            if close_detector.call(@lines[i].strip)
              @out << close_ph
              return i + 1
            end
            @out << _inline(@lines[i])
            i += 1
          end
          # End of input without finding the close: emit close anyway and
          # return. (Matches existing behavior — unterminated blocks still
          # produce a closing placeholder.)
          @out << close_ph
          i
        else
          # Single-block mode: consume up to the next blank line.
          while i < @lines.length && !@lines[i].strip.empty?
            @out << _inline(@lines[i])
            i += 1
          end
          @out << ""
          @out << close_ph
          i
        end
      end

      # Build a placeholder, returning "" instead of nil so callers can
      # append the result unconditionally. An invalid fragment (warned and
      # dropped by make_placeholder) makes the surrounding tag silently
      # disappear while the content it would have wrapped still renders.
      def _placeholder(html)
        TagProcessor.make_placeholder(html) || ""
      end

      # Process inline tag forms inside a single line:
      #   @{ .cls } word                 inline span wrapping the next word
      #   @{ .cls } phrase @{}           inline span wrapping the phrase
      #   @<el> word                     inline element wrapping the next word
      #   @<el attrs> phrase @</el>      inline element wrapping the phrase
      #   \@... (any of the above)       literal pass-through (backslash consumed)
      def _inline(line)
        return line unless line.include?('@')

        # Protect \@ escape sequences before any tag matching.
        result = line.gsub('\\@', ESCAPE_SENTINEL)

        if result.include?('@{')
          # @{ .cls } phrase @{}   → span around phrase (explicit close)
          result = _wrap_inline(
            result,
            /@\{([^}]+)\}(.*?)@\{\}/,
            open_html_for: ->(_m, attr_str) { "<span#{TagProcessor.build_attrs(attr_str)}>" },
            close_html:    "</span>",
            content_for:   ->(m) { m[2].strip }
          )

          # @{ .cls } word         → span around the next word (no close)
          result = _wrap_inline(
            result,
            /@\{([^}]+)\}\s*(\S+)/,
            open_html_for: ->(_m, attr_str) { "<span#{TagProcessor.build_attrs(attr_str)}>" },
            close_html:    "</span>",
            content_for:   ->(m) { m[2] }
          )
        end

        if result.include?('@<')
          # @<el attrs> phrase @</el>  → element around phrase (explicit close)
          result = _wrap_inline(
            result,
            /@<([a-zA-Z][a-zA-Z0-9_-]*)([^>]*)>(.*?)@<\/\1>/,
            open_html_for: ->(m, _attr_str) { "<#{m[1]}#{TagProcessor.build_attrs(m[2])}>" },
            close_html_for: ->(m) { "</#{m[1]}>" },
            content_for:    ->(m) { m[3].strip }
          )

          # @<el attrs> word           → element around the next word (no close)
          result = _wrap_inline(
            result,
            /@<([a-zA-Z][a-zA-Z0-9_-]*)([^>]*)>\s*(\S+)/,
            open_html_for: ->(m, _attr_str) { "<#{m[1]}#{TagProcessor.build_attrs(m[2])}>" },
            close_html_for: ->(m) { "</#{m[1]}>" },
            content_for:    ->(m) { m[3] }
          )
        end

        if result.include?('@#') || result.include?('@(#')
          # Full form @(# term) — empty anchor at this point with the term
          # registered. Never wraps. Run before the shorthand so the @#
          # inside @(# ... ) isn't consumed by the shorthand regex below.
          result = result.gsub(INDEX_FULL_RE) do
            term = Regexp.last_match(1).strip
            _emit_index_entry(term)
          end

          # Shorthand @# word — wraps the word; word IS the term. Word
          # is letters-only by INDEX_SHORTHAND_RE, so trailing punctuation
          # stays in the surrounding prose unwrapped.
          result = result.gsub(INDEX_SHORTHAND_RE) do
            word = Regexp.last_match(1)
            _emit_index_entry(word, word)
          end
        end

        # Restore escaped @-sigils (backslash consumed, bare @ remains).
        result.gsub(ESCAPE_SENTINEL, '@')
      end

      # Apply a single inline-form regex sweep, wrapping each match in
      # placeholders for open and close tags. Used by _inline for all four
      # inline forms (@{}-explicit, @{}-word, @<>-explicit, @<>-word).
      #
      # Either close_html (literal) or close_html_for (callable) must be
      # supplied; close_html_for takes precedence when given.
      def _wrap_inline(text, regex, open_html_for:, content_for:, close_html: nil, close_html_for: nil)
        text.gsub(regex) do
          m         = Regexp.last_match
          attr_str  = m[1]
          open_ph   = _placeholder(open_html_for.call(m, attr_str))
          close_ph  = _placeholder(close_html_for ? close_html_for.call(m) : close_html)
          "#{open_ph}#{content_for.call(m)}#{close_ph}"
        end
      end

      # Single walk through the document. Block-level constructs (@(), @{},
      # @[]) are detected here; their content lines are passed through the
      # inline processor _inline so @<> and inline @{} spans get handled.
      def run
        i = 0
        while i < @lines.length
          line = @lines[i].strip

          if line.start_with?('\\@')
            # Escaped @-sigil: strip the backslash, pass through as literal text.
            @out << @lines[i].sub('\\@', '@')
            i += 1
          elsif (m = line.match(INCLUDE_RE))
            _emit_include(m[1], m[2])
            i += 1
          elsif (m = line.match(DIRECTIVE_RE))
            _emit_directive(m[1])
            i += 1
          elsif (m = line.match(BLOCK_TAG_RE))
            attrs = TagProcessor.build_attrs(m[1])
            i = _scan_block(
              start_index:    i,
              open_html:      "<div#{attrs}>",
              close_html:     "</div>",
              close_detector: ->(stripped) { (cm = stripped.match(BLOCK_TAG_RE)) && cm[1].strip.empty? }
            )
          elsif (m = line.match(SEMANTIC_TAG_RE))
            element = m[1]
            attrs   = TagProcessor.build_attrs(m[2])
            i = _scan_block(
              start_index:    i,
              open_html:      "<#{element}#{attrs}>",
              close_html:     "</#{element}>",
              close_detector: ->(stripped) { (cm = stripped.match(SEMANTIC_CLOSE_RE)) && cm[1] == element }
            )
          else
            @out << _inline(@lines[i])
            i += 1
          end
        end

        @out.join("\n")
      end
    end
  end
end

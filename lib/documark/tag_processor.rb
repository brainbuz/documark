# frozen_string_literal: true

module Documark
  module TagProcessor
    # Matches a @{ ... } line that is the entire (stripped) line
    BLOCK_TAG_RE      = /\A@\{([^}]*)\}\z/
    # Matches a @[element attrs] line that is the entire (stripped) line
    SEMANTIC_TAG_RE   = /\A@\[([a-zA-Z][a-zA-Z0-9_-]*)([^\]]*)\]\z/
    # Matches a @[/element] closing line
    SEMANTIC_CLOSE_RE = /\A@\[\/([a-zA-Z][a-zA-Z0-9_-]*)\]\z/
    # Matches a @(name) Documark directive line
    DIRECTIVE_RE      = /\A@\(([a-z][a-z0-9-]*)\s*\)\z/
    # Finds self-describing placeholders in post-processed HTML.
    # The HTML to be restored is encoded directly inside the comment between
    # the :DMTAG markers, eliminating the need for a side-table registry.
    PLACEHOLDER_RE    = /<!--DMTAG:(.*?):DMTAG-->/m
    # Sentinel used internally to protect \@ escape sequences during inline processing
    ESCAPE_SENTINEL   = "\x00DMAT\x00"

    DEFAULT_TOC_DEPTH = 3

    module_function

    # Phase 1: replace @{} and @[] directives with self-describing HTML
    # comment placeholders. Returns the transformed body string. Markdown
    # content is left untouched so Kramdown processes it normally.
    #
    # opts may contain:
    #   "toc" => { "depth" => Integer (default 3), "title" => String|nil }
    def preprocess(body, opts = {})
      Preprocessor.new(body, opts || {}).run
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

    # Internal: walks the body line-by-line, replacing @{} and @[] directives
    # with self-describing HTML comment placeholders.
    #
    # Method-naming convention: methods prefixed with _ are internal helpers
    # not intended for external use. They aren't marked private because
    # nothing about calling them from outside would corrupt state, and the
    # _ prefix is sufficient signal to readers.
    class Preprocessor
      def initialize(body, opts = {})
        @lines       = body.lines(chomp: true)
        @out         = []
        @opts        = opts
        @toc_emitted = false
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

      # Dispatch a @(name) directive to its expansion handler.
      def _emit_directive(name)
        case name
        when 'toc'
          _emit_toc
        else
          raise StandardError, "Unknown Documark directive: @(#{name})"
        end
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
    end
  end
end

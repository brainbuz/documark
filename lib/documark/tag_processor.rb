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
    class Preprocessor
      def initialize(body, opts = {})
        @lines       = body.lines(chomp: true)
        @out         = []
        @opts        = opts
        @toc_emitted = false
      end

      def run
        i = 0
        while i < @lines.length
          line = @lines[i].strip

          if line.start_with?('\\@')
            # Escaped @-sigil: strip the backslash, pass through as literal text
            @out << @lines[i].sub('\\@', '@')
            i += 1
          elsif (m = line.match(DIRECTIVE_RE))
            emit_directive(m[1])
            i += 1
          elsif (m = line.match(BLOCK_TAG_RE))
            attrs        = TagProcessor.build_attrs(m[1])
            section_mode = @lines[i + 1].nil? || @lines[i + 1].strip.empty?
            open_ph      = placeholder("<div#{attrs}>")
            close_ph     = placeholder("</div>")

            if section_mode
              @out << open_ph
              @out << ""
              i += 1
              i += 1 while i < @lines.length && @lines[i].strip.empty?
              while i < @lines.length
                cur     = @lines[i].strip
                close_m = cur.match(BLOCK_TAG_RE)
                if close_m && close_m[1].strip.empty?
                  @out << close_ph
                  i += 1
                  break
                end
                @out << inline(@lines[i])
                i += 1
              end
            else
              @out << open_ph
              @out << ""
              i += 1
              while i < @lines.length && !@lines[i].strip.empty?
                @out << inline(@lines[i])
                i += 1
              end
              @out << ""
              @out << close_ph
            end

          elsif (m = line.match(SEMANTIC_TAG_RE))
            element      = m[1]
            attrs        = TagProcessor.build_attrs(m[2])
            section_mode = @lines[i + 1].nil? || @lines[i + 1].strip.empty?
            open_ph      = placeholder("<#{element}#{attrs}>")
            close_ph     = placeholder("</#{element}>")

            if section_mode
              @out << open_ph
              @out << ""
              i += 1
              i += 1 while i < @lines.length && @lines[i].strip.empty?
              while i < @lines.length
                cur     = @lines[i].strip
                close_m = cur.match(SEMANTIC_CLOSE_RE)
                if close_m && close_m[1] == element
                  @out << close_ph
                  i += 1
                  break
                end
                @out << inline(@lines[i])
                i += 1
              end
            else
              @out << open_ph
              @out << ""
              i += 1
              while i < @lines.length && !@lines[i].strip.empty?
                @out << inline(@lines[i])
                i += 1
              end
              @out << ""
              @out << close_ph
            end

          else
            @out << inline(@lines[i])
            i += 1
          end
        end

        @out.join("\n")
      end

      private

      # Wrap make_placeholder so callers can append the result unconditionally:
      # an invalid fragment (warned and dropped by make_placeholder) becomes
      # an empty string, so the surrounding tag silently disappears while the
      # content it would have wrapped still renders.
      def placeholder(html)
        TagProcessor.make_placeholder(html) || ""
      end

      # Dispatch a @(name) directive to its expansion handler.
      def emit_directive(name)
        case name
        when 'toc'
          emit_toc
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
      def emit_toc
        raise StandardError, "Multiple @(toc) directives are not supported" if @toc_emitted

        toc_opts = @opts.is_a?(Hash) ? (@opts['toc'] || {}) : {}
        depth    = (toc_opts['depth'] || DEFAULT_TOC_DEPTH).to_i
        title    = toc_opts['title']

        # Kramdown reads toc_levels as a document-level option. Inject it at
        # the very top of the output so it applies before the {:toc} marker.
        @out.unshift(%({::options toc_levels="1..#{depth}" /}), "")

        @out << placeholder(%(<nav id="toc">))
        if title && !title.to_s.strip.empty?
          @out << placeholder(%(<h2 class="toc-title">#{title}</h2>))
        end
        @out << ""
        @out << "* TOC"
        @out << "{:toc}"
        @out << ""
        @out << placeholder("</nav>")

        @toc_emitted = true
      end

      # Replace inline @{} span markers with placeholders.
      # Explicit close:  @{ .foo } some words @{}  → span wrapping "some words"
      # Unterminated:    @{ .foo } word             → span wrapping next word only
      # Escaped:         \@{ .foo }                → literal @{ .foo } (backslash consumed)
      def inline(line)
        return line unless line.include?('@')

        # Protect \@ escape sequences before any tag processing.
        result = line.gsub('\\@', ESCAPE_SENTINEL)

        if result.include?('@{')
          result = result.gsub(/@\{([^}]+)\}(.*?)@\{\}/) do
            open_ph  = placeholder("<span#{TagProcessor.build_attrs(Regexp.last_match(1))}>")
            close_ph = placeholder("</span>")
            "#{open_ph}#{Regexp.last_match(2).strip}#{close_ph}"
          end

          result = result.gsub(/@\{([^}]+)\}\s*(\S+)/) do
            open_ph  = placeholder("<span#{TagProcessor.build_attrs(Regexp.last_match(1))}>")
            close_ph = placeholder("</span>")
            "#{open_ph}#{Regexp.last_match(2)}#{close_ph}"
          end
        end

        if result.include?('@<')
          result = result.gsub(/@<([a-zA-Z][a-zA-Z0-9_-]*)([^>]*)>(.*?)@<\/\1>/) do
            element  = Regexp.last_match(1)
            attrs    = Regexp.last_match(2)
            content  = Regexp.last_match(3).strip
            open_ph  = placeholder("<#{element}#{TagProcessor.build_attrs(attrs)}>")
            close_ph = placeholder("</#{element}>")
            "#{open_ph}#{content}#{close_ph}"
          end

          result = result.gsub(/@<([a-zA-Z][a-zA-Z0-9_-]*)([^>]*)>\s*(\S+)/) do
            element  = Regexp.last_match(1)
            attrs    = Regexp.last_match(2)
            word     = Regexp.last_match(3)
            open_ph  = placeholder("<#{element}#{TagProcessor.build_attrs(attrs)}>")
            close_ph = placeholder("</#{element}>")
            "#{open_ph}#{word}#{close_ph}"
          end
        end

        # Restore escaped @-sigils (backslash consumed, bare @ remains)
        result.gsub(ESCAPE_SENTINEL, '@')
      end
    end
  end
end

# frozen_string_literal: true

module Documark
  module TagProcessor
    # Matches a @{ ... } line that is the entire (stripped) line
    BLOCK_TAG_RE      = /\A@\{([^}]*)\}\z/
    # Matches a @[element attrs] line that is the entire (stripped) line
    SEMANTIC_TAG_RE   = /\A@\[([a-zA-Z][a-zA-Z0-9_-]*)([^\]]*)\]\z/
    # Matches a @[/element] closing line
    SEMANTIC_CLOSE_RE = /\A@\[\/([a-zA-Z][a-zA-Z0-9_-]*)\]\z/
    # Finds placeholders in post-processed HTML
    PLACEHOLDER_RE    = /<!--DMTAG(\d+)-->/
    # Sentinel used internally to protect \@ escape sequences during inline processing
    ESCAPE_SENTINEL   = "\x00DMAT\x00"

    module_function

    # Phase 1: replace @{} and @[] directives with HTML comment placeholders.
    # Returns [body_with_placeholders, registry] where registry maps int → HTML string.
    # Markdown content is left untouched so Kramdown processes it normally.
    def preprocess(body)
      Preprocessor.new(body).run
    end

    # Phase 2: substitute placeholders emitted by preprocess with actual HTML tags.
    def postprocess(html, registry)
      html.gsub(PLACEHOLDER_RE) { registry[Regexp.last_match(1).to_i] || Regexp.last_match(0) }
    end

    # Convenience method: preprocess + postprocess without Kramdown in between.
    # Used directly by unit tests; real rendering goes through render_html.rb.
    def process(body)
      prepped, registry = preprocess(body)
      postprocess(prepped, registry)
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
    # with HTML comment placeholders and recording the real tags in a registry.
    class Preprocessor
      def initialize(body)
        @lines    = body.lines(chomp: true)
        @registry = {}
        @n        = 0
        @out      = []
      end

      def run
        i = 0
        while i < @lines.length
          line = @lines[i].strip

          if line.start_with?('\\@')
            # Escaped @-sigil: strip the backslash, pass through as literal text
            @out << @lines[i].sub('\\@', '@')
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

        [@out.join("\n"), @registry]
      end

      private

      def placeholder(html)
        key           = @n
        @registry[key] = html
        @n            += 1
        "<!--DMTAG#{key}-->"
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

# frozen_string_literal: true

module Documark
  # Single source of truth for @( if ) conditional content: condition
  # evaluation, true/else branch splitting, and depth-aware block scanning.
  #
  # Used by TagProcessor (the html/pdf preprocessing path, via the built-in
  # `if` directive) and by the standalone `resolve` pass for the markdown/text
  # export path, which does NOT go through TagProcessor.
  #
  # Condition grammar (no boolean combinators):
  #
  #   condition := '!' NAME          — negated truthy test
  #              | NAME              — truthy test
  #              | NAME '=' VALUE    — string equality
  #
  #   NAME  := /[A-Za-z_][A-Za-z0-9_-]*/   (top-level data keys only)
  #   VALUE := everything after the FIRST '=', stripped; one pair of matching
  #            surrounding quotes ('...' or "...") removed if present; may be
  #            empty.
  module Conditionals
    # A NAME: a top-level data key. Anchored — the whole condition side must match.
    NAME_RE = /\A[A-Za-z_][A-Za-z0-9_-]*\z/
    # A whole (stripped) line opening ANY block directive, with `begin` REQUIRED.
    # Mirrors TagProcessor::DIRECTIVE_RE but forces the begin token so this only
    # matches block openers. m[1]=name, m[2]=args, m[3]='begin'.
    OPEN_RE  = /\A@\(\s*([a-z][a-z0-9-]*)(?:\s+(.*?))?\s*(begin)\s*\)\z/
    # Closer for a block directive: @( end ). Same as TagProcessor::BLOCK_CLOSE_RE.
    CLOSE_RE = /\A@\(\s*end\s*\)\z/
    # The @( else ) branch separator inside an @( if ) block.
    ELSE_RE  = /\A@\(\s*else\s*\)\z/

    module_function

    # Evaluate a condition string against the document data hash. Returns
    # true/false. Raises StandardError on a malformed condition.
    def evaluate(condition, data)
      cond = condition.to_s.strip
      raise StandardError, "malformed @( if ) condition: #{condition.inspect}" if cond.empty?

      if cond.start_with?('!')
        name = cond[1..].strip
        malformed!(condition) if name.include?('=') || !name.match?(NAME_RE)
        !_truthy?(data, name)
      elsif cond.include?('=')
        name, value = cond.split('=', 2)
        name = name.strip
        malformed!(condition) unless name.match?(NAME_RE)
        _equal?(data, name, _unquote(value.strip))
      else
        malformed!(condition) unless cond.match?(NAME_RE)
        _truthy?(data, cond)
      end
    end

    # Split ONE if-block's content lines (opener and terminator already
    # removed) into [true_lines, else_lines]. A depth-0 @( else ) separates
    # the branches; nested blocks are transparent to the split. A second
    # depth-0 @( else ) is an error. No else → else_lines is [].
    def split_branches(lines)
      depth      = 0
      else_index = nil
      lines.each_with_index do |line, idx|
        stripped = line.strip
        if stripped.match?(OPEN_RE)
          depth += 1
        elsif stripped.match?(CLOSE_RE)
          depth -= 1
        elsif depth.zero? && stripped.match?(ELSE_RE)
          raise StandardError, "multiple @( else ) in one @( if ) block" unless else_index.nil?

          else_index = idx
        end
      end

      return [lines, []] if else_index.nil?

      [lines[0...else_index], lines[(else_index + 1)..]]
    end

    # Standalone recursive pass for markdown/text export. Resolves @( if )
    # blocks in-place — the chosen branch is spliced back into the walk so
    # nested ifs resolve naturally — and copies every other @( x begin )
    # block through verbatim (opener, raw content, terminator), interpreting
    # nothing inside it. Operates on chomped lines and rejoins with "\n".
    def resolve(text, data)
      lines = text.lines(chomp: true)
      out   = []
      i     = 0
      while i < lines.length
        line     = lines[i]
        stripped = line.strip
        if (m = stripped.match(OPEN_RE))
          content, after, terminated = _scan_block(lines, i)
          if m[1] == 'if'
            unless terminated
              warn "documark: @(if begin) was never closed — treating rest of document as block content"
            end
            true_lines, else_lines = split_branches(content)
            chosen = evaluate(m[2].to_s.strip, data) ? true_lines : else_lines
            # Splice the chosen branch back in at the current position and
            # re-walk it so nested ifs (and other blocks) resolve.
            lines[i...after] = chosen
          else
            # Foreign block: copy opener, raw content, and terminator through
            # untouched — nothing inside is interpreted.
            out << line
            out.concat(content)
            out << lines[after - 1] if terminated
            i = after
          end
          next
        elsif stripped.match?(ELSE_RE)
          raise StandardError, "unexpected @( else ) — no open @( if ... begin )"
        else
          out << line
          i += 1
        end
      end

      result = out.join("\n")
      text.end_with?("\n") ? "#{result}\n" : result
    end

    # ── Internal helpers ───────────────────────────────────────────────────────

    def malformed!(condition)
      raise StandardError, "malformed @( if ) condition: #{condition.inspect}"
    end

    # Truthiness of data[name]: falsy iff the value is nil (or the key is
    # missing), false, blank after to_s.strip, or "false" case-insensitively.
    # Everything else — including 0, "0", arrays, hashes — is truthy.
    def _truthy?(data, name)
      return false unless data.is_a?(Hash) && data.key?(name)

      value = data[name]
      return false if value.nil? || value == false

      s = value.to_s.strip
      return false if s.empty? || s.casecmp?('false')

      true
    end

    # String equality: missing key is always false. Otherwise compare
    # data[name].to_s (no strip on the data side) to the literal value.
    def _equal?(data, name, value)
      return false unless data.is_a?(Hash) && data.key?(name)

      data[name].to_s == value
    end

    # Remove one pair of matching surrounding quotes if present; else return
    # the string unchanged. An empty string stays empty.
    def _unquote(str)
      return str unless str.length >= 2

      first = str[0]
      return str[1..-2] if (first == "'" || first == '"') && str[-1] == first

      str
    end

    # Collect the content lines of the block opening at lines[start_index],
    # depth-aware. Returns [content, after_index, terminated]. content excludes
    # the opener and the matching @( end ); after_index is one past the close
    # (or end-of-input); terminated is false when the block was never closed.
    def _scan_block(lines, start_index)
      content = []
      depth   = 0
      i       = start_index + 1
      while i < lines.length
        stripped = lines[i].strip
        if stripped.match?(CLOSE_RE)
          return [content, i + 1, true] if depth.zero?

          depth -= 1
        elsif stripped.match?(OPEN_RE)
          depth += 1
        end
        content << lines[i]
        i += 1
      end
      [content, i, false]
    end
  end
end

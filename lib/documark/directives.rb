# frozen_string_literal: true

module Documark
  # Unified registry for every @() directive form. Both single-line
  # @(name args) and block @(name args begin)...@(end) directives are
  # registered here. The kind of directive is determined at registration
  # and validated against the form used in the document.
  #
  # Handler signature:
  #
  #   |args, content, ctx| -> { content: String, mode: :placeholder | :passthrough }
  #
  #   args    — raw String between directive name and ')' or 'begin )'
  #             (stripped; may be empty). Handlers parse args themselves.
  #   content — String for block forms (the raw text between opener and
  #             @( end ), verbatim, no inline processing applied).
  #             nil for single-line forms.
  #   ctx     — preprocessor instance; exposes ctx.data, ctx._placeholder,
  #             ctx.lines (for splicing), etc.
  #
  # Return value controls dispatch:
  #
  #   { content: '...', mode: :placeholder } — wrap content in a placeholder
  #                                            (invisible to Kramdown)
  #   { content: '...', mode: :passthrough } — splice content into the line
  #                                            stream so Kramdown processes it
  #   nil                                 — handler wrote directly to ctx
  #                                         (advanced; used by toc/index)
  module Directives
    NAME_RE = /\A[a-z][a-z0-9-]*\z/

    # :inline — single-line @(name args) only
    # :block  — block @(name args begin)...@( end ) only
    # :either — handler accepts both forms; content is nil for inline calls
    VALID_KINDS = %i[inline block either].freeze

    @handlers = {}

    module_function

    # Register a directive handler.
    #
    #   name    — lowercase identifier matching @(name ...).
    #   feature — providing feature name (required if non-nil).
    #   kind    — :inline, :block, or :either (default :either).
    def register(name, feature: nil, kind: :either, &handler)
      raise ArgumentError, "register requires a block"               unless block_given?
      raise ArgumentError, "invalid directive name: #{name.inspect}" unless name.to_s.match?(NAME_RE)
      raise ArgumentError, "invalid kind: #{kind.inspect}"           unless VALID_KINDS.include?(kind)
      if feature && !Documark::Plugins.feature?(feature)
        raise ArgumentError, "unknown feature '#{feature}' — register it with Plugins.register first"
      end

      @handlers[name.to_s] = {
        handler: handler,
        feature: feature && feature.to_s,
        kind:    kind
      }
    end

    def lookup(name)
      entry = @handlers[name.to_s]
      entry && entry[:handler]
    end

    def kind_for(name)
      entry = @handlers[name.to_s]
      entry && entry[:kind]
    end

    def feature_for(name)
      entry = @handlers[name.to_s]
      entry && entry[:feature]
    end

    def registered
      @handlers.keys
    end
  end
end
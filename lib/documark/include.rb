# frozen_string_literal: true

module Documark
  # Include's own narrow sub-registry mapping type names to converter
  # blocks and file extensions to type names. The @( include ) directive
  # consults this when dispatching.
  #
  # Built-in types (markdown, html, text) are registered here at
  # require-time, with no special-casing inside the directive handler.
  # Plugins extend include via FeatureBuilder#extends_include.
  #
  # A converter block has the signature:
  #
  #   |content, args, ctx| -> { content: String, mode: :placeholder | :passthrough }
  #
  #   content — full text of the included file (String)
  #   args    — raw argument string from @( include args... ) after the
  #             type token has been parsed out (currently unused; reserved
  #             for future per-include options)
  #   ctx     — preprocessor instance; gives access to ctx.data
  #
  # Return mode controls how the result is injected:
  #
#   :placeholder — content is wrapped in a placeholder, invisible to Kramdown
#   :passthrough — content is spliced into the line stream so Kramdown sees it
  module Include
    NAME_RE = /\A[a-z][a-z0-9-]*\z/

    @handlers = {}
    @exts     = {}

    module_function

    # Register a converter for one include type.
    #
    #   type       — lowercase identifier matching the explicit type token
    #                in @( include 'path' <type> ).
    #   feature    — providing feature name (required for non-built-in types).
    #   extensions — array of file extensions (with leading dot) for auto-detect.
    def register_type(type, feature: nil, extensions: [], &handler)
      raise ArgumentError, "register_type requires a block"             unless block_given?
      raise ArgumentError, "invalid include type: #{type.inspect}"      unless type.to_s.match?(NAME_RE)
      if feature && !Documark::Plugins.feature?(feature)
        raise ArgumentError, "unknown feature '#{feature}' — register it with Plugins.register first"
      end

      key = type.to_s
      @handlers[key] = { handler: handler, feature: feature && feature.to_s, exts: extensions.map(&:downcase) }
      extensions.each { |ext| @exts[ext.downcase] = key }
    end

    def lookup_type(name)
      entry = @handlers[name.to_s]
      entry && entry[:handler]
    end

    def lookup_by_ext(ext)
      @exts[ext.to_s.downcase]
    end

    def feature_for(name)
      entry = @handlers[name.to_s]
      entry && entry[:feature]
    end

    def exts_for(name)
      entry = @handlers[name.to_s]
      entry && entry[:exts]
    end

    def registered
      @handlers.keys
    end
  end
end
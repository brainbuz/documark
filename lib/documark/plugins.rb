# frozen_string_literal: true

module Documark
  # Plugin discovery and feature registry.
  #
  # A plugin is a Ruby file under `lib/documark/plugin/<name>.rb` in this
  # repository or in any installed gem on the load path. At startup the
  # CLI calls Documark::Plugins.discover!, which finds every such file
  # via Gem.find_files and requires it.
  #
  # The primary plugin entry point is:
  #
  #   Documark::Plugins.register('myfeature', plugin: 'myfeature') do |f|
  #     f.register_directive 'mything' do |args, content, ctx|
  #       { content: '...', mode: :placeholder }
  #     end
  #   end
  #
  # Hard-fail policy: if a plugin file is on the load path it MUST load
  # completely. A plugin that fails to require (missing dep, syntax
  # error) fails the entire Documark invocation with a clear error.
  module Plugins
    FEATURE_NAME_RE = /\A[a-z][a-z0-9-]*\z/

    @discovered = false
    @loaded     = []
    @features   = {}

    module_function

    def discover!(verbose: false)
      return @loaded if @discovered

      @discovered = true
      Gem.find_files('documark/plugin/*.rb').uniq.each do |path|
        name = File.basename(path, '.rb')
        begin
          require path
        rescue LoadError, StandardError => e
          raise StandardError,
                "documark: plugin '#{name}' failed to load (#{e.class}: #{e.message})\n" \
                "  path: #{path}\n" \
                "  install the plugin's third-party dependencies, or remove the plugin file."
        end
        @loaded << name
        warn "documark: loaded plugin '#{name}'" if verbose
      end
      @loaded
    end

    def loaded
      @loaded.dup
    end

    # Register a named feature and optionally its capabilities via a block.
    # Yields a FeatureBuilder if a block is given. This is the primary
    # registration entry point for both plugins and core features.
    def register(name, description: nil, plugin: nil, &block)
      register_feature(name, description: description, plugin: plugin)
      yield FeatureBuilder.new(name.to_s) if block_given?
    end

    # Low-level feature metadata registration. Prefer Plugins.register.
    def register_feature(name, description: nil, plugin: nil)
      raise ArgumentError, "invalid feature name: #{name.inspect}" unless name.to_s.match?(FEATURE_NAME_RE)

      key = name.to_s
      warn "documark: feature '#{key}' is being re-registered (was '#{@features[key][:plugin]}', now '#{plugin}')" if @features.key?(key)
      @features[key] = { description: description, plugin: plugin && plugin.to_s }
    end

    def feature?(name)
      @features.key?(name.to_s)
    end

    def features
      @features.dup
    end

    def require_features!(list, source:)
      names = Array(list).map(&:to_s).reject(&:empty?)
      return if names.empty?

      missing = names.reject { |n| feature?(n) }
      return if missing.empty?

      raise StandardError,
            "documark: required feature(s) not available: #{missing.map { |m| "'#{m}'" }.join(', ')}\n" \
            "  required by: #{source}\n" \
            "  install the providing plugin, or remove the requirement."
    end
  end
end

require_relative 'directives'
require_relative 'include'
require_relative 'targets'
require_relative 'conditionals'

module Documark
  module Plugins
    # Yields from Plugins.register so a plugin can declare its capabilities
    # without referencing registry modules directly.
    class FeatureBuilder
      def initialize(feature_name)
        @feature = feature_name
      end

      # Register an @() directive handler.
      # Handler signature: (args, content, ctx) -> { content:, mode: } or nil
      #   args    — string between name and ')' or 'begin )', stripped, may be ''
      #   content — String for block form; nil for inline form
      #   ctx     — preprocessor instance (ctx.data, ctx._placeholder, ctx.base_path)
      #
      # form: — :either (default), :block (must be @( name begin )...@( end )),
      #         or :inline (must be @( name )). The default works for handlers
      #         that ignore content; specify :block or :inline to get clearer
      #         errors when documents use the wrong form.
      def register_directive(name, form: :either, &handler)
        Directives.register(name, feature: @feature, kind: form, &handler)
      end

      # Contribute a file converter to the include directive.
      # Handler signature: (content, args, ctx) -> { content:, mode: }.
      def extends_include(type:, extensions: [], &handler)
        Include.register_type(type, feature: @feature, extensions: extensions, &handler)
      end

      # Register a new output target. Handler receives the render context.
      def register_target(name, &handler)
        Targets.register(name, feature: @feature, &handler)
      end
    end
  end
end

# ── Built-in feature registrations ────────────────────────────────────────────
module Documark
  module Plugins
    # @( include 'path' [type] ) — built-in extensible directive.
    register('include', plugin: 'core', description: '@( include ) directive') do |f|
      f.register_directive('include', form: :inline) do |args, _content, ctx|
        m = args.match(Documark::Include::ARG_RE)
        unless m
          raise StandardError,
                "documark: malformed include directive: @( include #{args} )\n" \
                "Expected: @( include 'path' [type] ) — path may be bare " \
                "if it contains no whitespace or quote characters."
        end

        rel_path      = m[1] || m[2] || m[3]
        type_override = m[4]
        abs_path      = File.expand_path(rel_path, ctx.base_path)
        content       = begin
          File.read(abs_path)
        rescue Errno::ENOENT
          raise StandardError, "documark: include file not found: #{abs_path}"
        end

        ext  = File.extname(abs_path).downcase
        type = type_override || Documark::Include.lookup_by_ext(ext) || 'text'

        converter = Documark::Include.lookup_type(type)
        unless converter
          feature_hint =
            if Documark::Plugins.feature?(type)
              "feature '#{type}' is registered but no include handler is bound to it."
            else
              "no plugin provides include type '#{type}' — install the providing plugin."
            end
          raise StandardError,
                "documark: unknown @( include ) type #{type.inspect} — #{feature_hint}"
        end

        converter.call(content, args, ctx)
      end

      # Built-in include type handlers.
      f.extends_include(type: 'markdown', extensions: %w[.md .markdown]) do |content, _args, _ctx|
        { content: content, mode: :passthrough }
      end

      f.extends_include(type: 'html', extensions: %w[.html]) do |content, _args, _ctx|
        { content: content, mode: :placeholder }
      end

      f.extends_include(type: 'text', extensions: []) do |content, _args, _ctx|
        fenced = "```\n#{content.chomp}\n```"
        { content: fenced, mode: :passthrough }
      end
    end

    register('toc', plugin: 'core', description: '@(toc) directive') do |f|
      f.register_directive('toc', form: :inline) do |_args, _content, ctx|
        ctx._emit_toc
        nil
      end
    end

    register('index', plugin: 'core', description: '@(index) directive') do |f|
      f.register_directive('index', form: :inline) do |_args, _content, ctx|
        ctx._emit_index
        nil
      end
    end

    register('if', plugin: 'core', description: '@( if ) conditional content') do |f|
      f.register_directive('if', form: :block) do |args, content, ctx|
        keep = Documark::Conditionals.evaluate(args, ctx.data)
        true_lines, else_lines = Documark::Conditionals.split_branches(content.lines(chomp: true))
        chosen = keep ? true_lines : else_lines
        chosen.empty? ? nil : { content: chosen.join("\n"), mode: :passthrough }
      end
    end

    # Targets are stub-registered here so feature validation works at parse time.
    # The real handlers (which invoke the render pipeline) are registered in
    # bin/documark after all rendering modules have been mixed in.
    register('html', plugin: 'core', description: 'HTML output') do |f|
      f.register_target('html') { raise NotImplementedError }
    end

    register('pdf', plugin: 'core', description: 'WeasyPrint PDF output') do |f|
      f.register_target('pdf') { raise NotImplementedError }
    end

    register('markdown', plugin: 'core', description: 'Kramdown-rendered Markdown') do |f|
      f.register_target('markdown') { raise NotImplementedError }
    end

    register('text', plugin: 'core', description: 'Plain text output') do |f|
      f.register_target('text') { raise NotImplementedError }
    end

    register('epub', plugin: 'core', description: 'EPUB output (reserved)') do |f|
      f.register_target('epub') { raise NotImplementedError }
    end

    # Container packing/unpacking. No capabilities; exists so documents and
    # layouts can gate on it via `requires: [container]`.
    register('container', plugin: 'core', description: 'packed document container (.dmc/.dms)')
  end
end
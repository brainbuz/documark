# frozen_string_literal: true

module Documark
  # Registry for output targets (-t <name> on the CLI). Built-in targets
  # register here so they participate in feature validation; the actual
  # rendering handlers are registered in bin/documark after the rendering
  # modules are mixed in.
  module Targets
    NAME_RE = /\A[a-z][a-z0-9-]*\z/

    @handlers = {}

    module_function

    def register(name, feature: nil, &handler)
      raise ArgumentError, "register requires a block" unless block_given?
      raise ArgumentError, "invalid target name: #{name.inspect}" unless name.to_s.match?(NAME_RE)
      if feature && !Documark::Plugins.feature?(feature)
        raise ArgumentError, "unknown feature '#{feature}' — register it with Plugins.register first"
      end

      @handlers[name.to_s] = { handler: handler, feature: feature && feature.to_s }
    end

    def lookup(name)
      entry = @handlers[name.to_s]
      entry && entry[:handler]
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
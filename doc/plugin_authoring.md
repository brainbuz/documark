# Documark Plugin Authoring Guide

A Documark plugin is a Ruby file that contributes new capabilities to the Documark processing pipeline. Plugins are discovered automatically at startup.

## The mental model

A Documark document is mostly Markdown plus `@()` directives. Every `@()` tag has the same shape:

```
@( <name> [args...] )                       single-line
@( <name> [args...] begin ) ... @( end )    block
```

The first word inside the parens is the **directive name**. The rest, up to `)` or `begin )`, is an opaque **args string** the handler parses for itself. If the tag ends with `begin`, everything between it and the matching `@( end )` is the **content**, collected verbatim.

A plugin does one of two things:

1. **Register a new directive** — introduce a new `@(name ...)` form. Examples: the asciidoc plugin registers `@( asciidoc begin )...@( end )` and `@( talltable begin )...@( end )`.
2. **Extend an existing extensible directive** — contribute a file converter to the built-in `include` directive, or add a new output target. Examples: asciidoc extends `include` to handle `.adoc` files.

Today the only built-in extensible directive is `include`. The pattern is designed so other directives can be made extensible the same way without changing the plugin API surface.

## File location and discovery

A plugin is any Ruby file at:

```
lib/documark/plugin/<name>.rb
```

in any directory on the Ruby load path — whether in this repository, in a gem, or added manually. At startup, `Documark::Plugins.discover!` finds every such file via `Gem.find_files` and requires it.

**Hard-fail policy:** if a plugin file is present and fails to load for any reason (missing gem dependency, syntax error), the entire Documark invocation fails with a clear error. There is no soft-fail or skip-and-warn path. Users who do not want a plugin's dependencies should not install the plugin file.

## Registration API

All registration goes through one call:

```ruby
Documark::Plugins.register('feature-name', plugin: 'plugin-file-name',
  description: 'What this feature does') do |f|
  # capability declarations here
end
```

The block receives a `FeatureBuilder` (`f`) with three methods.

### `f.register_directive 'name', form: :either { |args, content, ctx| ... }`

Register a handler for `@( name args )` or `@( name args begin ) ... @( end )`. The same method covers both forms; `content` is the block text (for block form) or `nil` (for single-line form).

```ruby
# Block form — handler uses content
f.register_directive 'myformat', form: :block do |args, content, ctx|
  # args    — raw text between 'myformat' and 'begin )' (stripped, may be '')
  # content — raw text between opener and @( end ), verbatim (no inline processing)
  # ctx     — preprocessor instance: ctx.data, ctx.base_path, ctx._placeholder
  { content: MyFormat.render(content), mode: :placeholder }
end

# Single-line form — content is nil
f.register_directive 'now', form: :inline do |_args, _content, _ctx|
  { content: "<time>#{Time.now}</time>", mode: :placeholder }
end
```

The `form:` argument is optional and defaults to `:either`. Pass `:block` or `:inline` to get a clear error if a document uses the wrong form (e.g. `@(asciidoc)` instead of `@( asciidoc begin )`). Leave it off if your handler genuinely accepts both.

### `f.extends_include type:, extensions: { |content, args, ctx| ... }`

Adds a file converter to the built-in `include` directive.

```ruby
f.extends_include type: 'asciidoc', extensions: %w[.adoc .asciidoc] do |content, _args, _ctx|
  # content — full text of the included file
  # args    — full args from the @( include ... ) directive (path + optional type token)
  # ctx     — preprocessor instance
  { content: MyConverter.to_html(content), mode: :placeholder }
end
```

- `type:` is the explicit type token authors can write: `@( include 'file.adoc' asciidoc )`.
- `extensions:` lists file extensions (with leading dot) for auto-detection.

### `f.register_target 'name' { |ctx| ... }`

Adds a new `-t name` output format.

```ruby
f.register_target 'slides' do |ctx|
  # ctx['output'] — output file path
  # ctx['page']   — rendered HTML string (for HTML-pipeline targets)
  # ctx['layout'] — layout hash
  # ctx['doc']    — parsed document hash
  File.write(ctx['output'], SlideRenderer.convert(ctx['page']))
end
```

## The handler return value

Directive handlers (`register_directive`) and include-type handlers (`extends_include`) return one of:

```ruby
{ content: '<some html>', mode: :placeholder }
```

The content is wrapped in a placeholder and is invisible to Kramdown. Use this for self-contained HTML fragments that should appear in the output exactly as-is.

```ruby
{ content: "some **markdown** text", mode: :passthrough }
```

The text is spliced into the markdown line stream at the directive's position, as if it had been typed there. Kramdown processes it. Use this for content that should participate in the surrounding Markdown rendering.

```ruby
nil
```

The handler wrote directly to `ctx` itself. Advanced — used by the built-in `toc` and `index` directives that need to manipulate the line stream and registry directly.

## A complete plugin

The AsciiDoc plugin at `plugins/asciidoc/lib/documark/plugin/asciidoc.rb` is the canonical reference:

```ruby
# frozen_string_literal: true
require 'asciidoctor'
require 'nokogiri'

module Documark
  module Plugin
    module Asciidoc
      module_function

      def convert(content)
        html = ::Asciidoctor.convert(content, safe: :safe, header_footer: false)
        # ... strip structural classes ...
      end
    end
  end
end

Documark::Plugins.register('asciidoc', plugin: 'asciidoc',
  description: 'AsciiDoc includes and inline blocks via Asciidoctor') do |f|

  f.extends_include type: 'asciidoc', extensions: %w[.adoc .asciidoc] do |content, _args, _ctx|
    { content: Documark::Plugin::Asciidoc.convert(content), mode: :placeholder }
  end

  f.register_directive 'asciidoc' do |_args, content, _ctx|
    { content: Documark::Plugin::Asciidoc.convert(content), mode: :placeholder }
  end
end

Documark::Plugins.register('talltable', plugin: 'asciidoc',
  description: 'AsciiDoc block directive for tall/complex tables') do |f|
  f.register_directive 'talltable' do |_args, content, _ctx|
    { content: Documark::Plugin::Asciidoc.convert(content), mode: :placeholder }
  end
end
```

One plugin file, three features (`asciidoc`, `talltable`), four registrations: one include contribution, two block directives, plus the implicit feature metadata.

## Multiple features from one plugin file

A single plugin file may register multiple features. Each `Plugins.register` call is independent. Documents declare each feature they need:

```yaml
requires:
  - asciidoc
  - talltable
```

## The `requires:` contract

Documents and layouts declare which features they depend on:

```yaml
title: "My Document"
requires:
  - asciidoc
```

The processor validates every named feature is loaded before processing begins. A missing feature is a hard error with a clear message. Plugin authors should document which feature name(s) documents must declare.

## Validation

`FeatureBuilder` registers the feature before yielding, so all capability registrations within the block can name `@feature` safely. Calling the underlying registries directly (e.g. `Documark::Directives.register`) requires the feature to already exist — otherwise `ArgumentError` is raised immediately.

## Testing a plugin

```ruby
require_relative '../lib/documark/plugins'
require_relative '../lib/documark/plugin/myplugin'

class MyPluginTest < Minitest::Test
  def test_feature_registered
    assert Documark::Plugins.feature?('myplugin')
  end

  def test_directive_registered
    assert_includes Documark::Directives.registered, 'myplugin'
    assert_equal 'myplugin', Documark::Directives.feature_for('myplugin')
    assert_equal :block, Documark::Directives.kind_for('myplugin')
  end

  def test_include_type_registered
    assert_includes Documark::Include.registered, 'myplugin'
  end

  def test_renders_correctly
    body = "@(myplugin begin)\nsome content\n@( end )"
    result = Documark::TagProcessor.process(body)
    assert_includes result, '<expected output>'
  end
end
```

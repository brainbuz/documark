# Documark AsciiDoc Plugin

Provides AsciiDoc rendering support for Documark via Asciidoctor.

## Features

- `asciidoc`: Include and inline block directive for AsciiDoc content
- `talltable`: Semantic alias for AsciiDoc-rendered tables

## Dependencies

- `asciidoctor`
- `nokogiri`
- `logger` (bundled in Ruby 4.0+)

## Installation

Add to your Gemfile:

```ruby
gem 'documark-plugin-asciidoc'
```

Or install directly:

```sh
gem install documark-plugin-asciidoc
```

## Usage

In your `.dm` document, require the plugin:

```yaml
!! documark

requires: [asciidoc]
```

Then use the `@(asciidoc)` directive or include `.adoc` files:

```
@( asciidoc
= Section Title

Some AsciiDoc content.
@( end )
```

Or include a file:

```
@( include 'document.adoc' )
```

The plugin strips structural CSS classes from the generated HTML, preserving only syntax-highlighting classes like `language-*` for code blocks.

# Documark Implementation Notes

This document describes the current Ruby prototype implementation.

It is not the specification. When the implementation and the spec differ, that difference should be treated as an active design question rather than assumed to be the final format rule.

## Overview

The current executable is [bin/documark](../bin/documark).

The implementation is organized into a few small modules:

- parser: reads the Documark header, extracts sections, and parses metadata
- config: loads user config and supports config/template helper commands
- HTML renderer: converts Markdown to HTML and injects the selected layout
- PDF renderer: prints generated HTML to PDF through a headless browser

Main source files:

- [lib/documark/parser.rb](../lib/documark/parser.rb)
- [lib/documark/config.rb](../lib/documark/config.rb)
- [lib/documark/render_html.rb](../lib/documark/render_html.rb)
- [lib/documark/render_pdf.rb](../lib/documark/render_pdf.rb)
- [lib/documark/html.erb](../lib/documark/html.erb)

## Processing Flow

For the `process` action, the prototype currently does the following:

1. Merge built-in defaults, config-file settings, and CLI options.
2. Read the input file.
3. Require a Documark header on the first line.
4. Split the input into the `data`, optional `layout`, and body sections.
5. Parse the `data` section as YAML.
6. Resolve layout from the document or the configured default layout file.
7. Render the Markdown body to HTML.
8. Write HTML directly, print to PDF, or emit Markdown-style body output depending on target.

## Current Document Expectations

The prototype currently expects:

- a top-level header such as `!! documark document`
- a `data` block in document inputs
- an optional inline `layout` block
- the remaining content to be Markdown body text

This is stricter than the current prototype spec in some places. That is intentional for now.

## YAML Handling

The implementation uses a restricted YAML loader.

Current behavior:

- YAML aliases are disabled
- metadata is expected to parse into ordinary data structures
- `lang` is currently copied to `language` if `language` is absent

The `data` block is used for values such as document title and language.

## Layout Handling

Layouts are either:

- embedded inline inside a document with `!! layout` ... `!! end`
- loaded from a default `.dml` template file

Inside the layout block, the prototype expects:

1. a YAML front matter block delimited by `---`
2. raw CSS after the closing delimiter

The CSS portion is important enough to have its own guide: [Layout Style Guide](layout-style.md).

Useful layout keys today:

- `stylesheets`
- `container_class`

The generated HTML template then inserts:

- the title
- the language attribute on the root HTML element
- stylesheet links
- inline CSS from the layout
- the rendered body HTML inside a wrapper container

## Markdown Engine

The current Ruby prototype uses Kramdown to render body content.

That is an implementation choice, not yet a locked format commitment.

If Markdown dialect becomes a compatibility problem, the project may later define a Documark dialect.

## Output Targets

### HTML

The prototype renders the body to HTML and writes a full HTML document.

### PDF

The prototype renders HTML first, then asks a Chromium-compatible browser to print that HTML to PDF in headless mode. When rendering for PDF the container_class is omitted, because the padding from a typical container class will be added to the page-margin specified in the style section. Mozilla browsers' headless mode doesn't have the capability that Chrome based browsers do.

The default browser path is currently `/usr/bin/google-chrome`, but this can be overridden in config or on the command line.

### Markdown and Text

For `markdown` and `text`, the prototype writes the body section rather than a full transformed document.

It also strips common Kramdown attribute-list syntax during output cleanup.

### EPUB

The CLI recognizes `epub`, but the target is not implemented.

## Configuration

The implementation currently reads an optional config from one of these locations if present:

- `~/.documark/documark.conf`
- `~/.documark.conf`

Common config keys:

- `default_layout`
- `browser`
- `template_folder`

The `config_new` and `template_new` actions exist to help create starter files interactively.

An example config file lives at [doc/examples/example_conf.conf](examples/example_conf.conf).

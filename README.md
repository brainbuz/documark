# Documark

Documark is a prototype document format and toolchain for writing fully styled, structured documents in plain text.

The project starts from a simple premise: Markdown is a good authoring format, but modern document workflows also need stable metadata, reusable layout, and reliable output for the web and print. Documark explores how far that can be pushed without falling back to opaque word processor files.

Current priorities:

- define the format in public, even while it is still a prototype
- keep documents human-readable and easy to edit by hand
- support styled HTML and printable PDF output
- separate document content from reusable layout where practical

## Status

Documark is in the prototype stage.

That has two consequences:

- the format is still being shaped and the spec may intentionally stay ahead of, or diverge from, the current implementation
- the current Ruby implementation is a reference prototype, not the final definition of the format

## Documentation

- [Specification](doc/documark_spec.md)
- [Implementation Notes](doc/implementation.md)
- [Layout Style Guide](doc/layout-style.md)
- [Project Philosophy](doc/philosophy.md)
- [Examples](doc/examples)
- [Developer Notes](doc/devnotes/README.md)

## What The Prototype Does Today

The current implementation can:

- parse Documark document files with a Documark header and named blocks
- read a `data` block for document metadata
- read either an inline `layout` block or a default layout template
- render Markdown content to HTML
- render PDF from generated HTML via the WeasyPrint command-line renderer
- write raw Markdown-style body output for `markdown` and `text` targets
- conditionally include or exclude content with `@( if CONDITION begin ) ... @( else ) ... @( end )`, evaluated against document data and `--define` overrides, uniformly across every output target
- pack a document (or layout) together with its local supporting files — images, stylesheets, includes — into a single portable container file, and unpack one back into a document plus its asset tree
- render against an external layout or "stationery" file via `--layout`, including stationery files that carry their own packed assets

Current output targets:

- `html`
- `pdf`
- `markdown`
- `text`

`epub` is reserved in the CLI but not implemented.

## Quick Start

### 1. Install dependencies

This prototype is implemented in Ruby.

```sh
bundle install
```

For PDF output, Documark calls the [WeasyPrint](https://weasyprint.org/) command-line renderer. WeasyPrint is a Python package, not a Ruby gem, so install it separately:

```sh
# Debian / Ubuntu
sudo apt install weasyprint

# Or via pip
pip install weasyprint
```

The `weasyprint` executable must be on `PATH`. If it isn't, `documark process -t pdf` fails with an install-instruction message; HTML, Markdown, and text targets work without it.

### 2. Render an example to HTML

```sh
bundle exec bin/documark process \
	--input doc/examples/simple.dm \
	--output /tmp/documark-example.html \
	--target html
```

### 3. Render an example to PDF

```sh
bundle exec bin/documark process \
	--input doc/examples/simple-with-layout.dm \
	--output /tmp/documark-example.pdf \
	--target pdf
```

## CLI Overview

The executable is [bin/documark](bin/documark).

Actions:

- `process`
- `pack`
- `unpack`
- `config_new`
- `template_new`

Common options for `process`:

- `--input` / `-i`
- `--output` / `-o`
- `--target` / `-t`
- `--config` / `-c`
- `--verbose` / `-v`
- `--debug` / `-d`
- `--define` — set a document data key (`key=value` or a bare `key`), repeatable; overrides the document's own `data` block, e.g. for `@( if )` conditions
- `--layout` — layout or stationery (`.dms`) file to render against, overriding `default_layout` from config

Example:

```sh
bundle exec bin/documark process -i input.dm -o output.html -t html
```

`pack` bundles a document (or layout) together with its discovered local assets into a single container file:

```sh
bundle exec bin/documark pack -i input.dm -o input.dmc
```

`unpack` reverses it, writing the document plus its extracted asset tree into a directory:

```sh
bundle exec bin/documark unpack -i input.dmc -o input-unpacked/
```

## Plugins and Features

Documark functionality is organized into named **features**. Built-in features (`markdown`, `html`, `pdf`, `text`, `epub`, `toc`, `index`, `include`, `if`, `container`) ship with every install. **Plugins** are independent Ruby files (typically in separate gems) that register additional features at startup. See `doc/documark_spec.md` §9 for the full contract.

A document or layout may declare a `requires:` array in its YAML to fail fast when an expected feature isn't available:

```text
!! documark document
!! data
title: "Quarterly Report"
requires:
  - asciidoc
  - pdf
!! end
```

This repository includes the optional `asciidoc` plugin as a separate gem under `plugins/asciidoc/`. It activates `@( include 'foo.adoc' )` by routing the file through Asciidoctor. In monorepo development and CI, the Gemfile resolves this plugin from the local path so tests always run against checked-out code. Installing the core `documark` gem alone does not install or load AsciiDoc dependencies.

```sh
bundle install
```

To emulate release-style dependency resolution (without local path plugins), set `DOCUMARK_RELEASE_DEPS=1`.

Plugin tests in `plugins/asciidoc/test/` load core Documark directly from the repository `lib/` path (load-path precedence) rather than through an installed `documark` gem, to avoid stale cached gem copies during active development.

Plugin load failures are hard fails: if a plugin file is present, it must load completely with all of its dependencies, or the whole invocation aborts with a clear error naming the plugin and the missing dependency.

## Example Document

```text
!! documark document
!! data
title: "A Simple Documark Document"
language: en
!! end

# Hello

This is a Documark document.
```

See [doc/examples/simple.dm](doc/examples/simple.dm) and [doc/examples/simple-with-layout.dm](doc/examples/simple-with-layout.dm) for working examples.

## Project Direction

The project is trying to answer a format question, not just ship a converter.

Key themes:

- a document format should be inspectable without special software
- layout should be explicit rather than hidden in binary application state
- print output matters and should not be treated as a second-class export path
- the specification should be written early, even if it changes during the prototype phase

The longer-term goal is to help define an open, text-based standard for richly formatted documents.

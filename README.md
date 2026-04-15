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

- [Specification](doc/spec.md)
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
- render PDF by printing generated HTML through a headless browser
- write raw Markdown-style body output for `markdown` and `text` targets

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

For PDF output you also need a Chromium-compatible browser available on disk. The current default is:

```text
/usr/bin/google-chrome
```

If your browser lives elsewhere, pass `--browser` or set it in config.

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
- `config_new`
- `template_new`

Common options for `process`:

- `--input` / `-i`
- `--output` / `-o`
- `--target` / `-t`
- `--browser` / `-b`
- `--config` / `-c`
- `--verbose` / `-v`
- `--debug` / `-d`

Example:

```sh
bundle exec bin/documark process -i input.dm -o output.html -t html
```

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
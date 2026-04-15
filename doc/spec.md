# Documark Specification (Draft)

Status: Draft

This document defines the current Documark format and processing behavior as implemented in this repository.

## 1. Scope

Documark is an extended Markdown format for styled, structured documents.

- Primary source format: `.dm` (document) and `.dml` (layout template)

This draft describes both format rules and processor behavior that affect output.

## 2. Conformance Language

The key words "MUST", "MUST NOT", "SHOULD", "SHOULD NOT", and "MAY" are to be interpreted as described in RFC 2119.

## 3. Top-Level Structure

A Documark file MUST begin with a Documark header directive on line 1.

### 3.1 Header Directive

General form:

```text
!! <context> [type-or-token] [key=value]...
```

Examples:

```text
!! documark document
!! documark layout
!! documark document option=baz
```

Rules:

- The first directive context MUST be `documark`.
- The second directive declares the `type` of resource.
- Additional tokens in `key=value` may be given to declare features and options, currently none of these have been defined.
- The header is case insensitive, by convention is in lowercase.

### 3.2 Block Directives

Named blocks use opening and closing directives:

```text
!! <name>
...block content...
!! end
```

Supported block names:

- `data`
- `layout`

Blank lines between major sections are allowed.

## 4. Document File (`type=document`)

A document file contains:

1. Required top-level header: `!! documark document` (additional tokens allowed)
2. Required `data` block
3. Optional `layout` block
4. Markdown body (remaining content)

Minimal valid document:

```text
!! documark document
!! data
title: "Example"
!! end

# Heading
Body text.
```

### 4.1 Data Block

The `data` block content is parsed as YAML using safe load behavior.

Rules:

- A `data` block SHOULD be present.
- YAML aliases are not permitted.
- Parsed YAML SHOULD be a mapping object.

Common keys:

- `title`: document title for HTML output
- `language` or `lang`: document language for HTML `lang` attribute

## 5. Layout File (`type=layout`)

A layout template file is typically `.dml` and structured as:

1. Header: `!! documark layout`
2. Required `layout` block

Example skeleton:

```text
!! documark layout
!! layout
---
stylesheets:
	- "https://cdn.example.com/site.css"
container_class: container
---

@media print {
	@page { size: letter portrait; margin: 1in; }
}
!! end
```

### 5.1 Layout Block Internal Format

The `layout` block is split into two parts:

1. YAML front matter delimited by `---` and `---`
2. Remaining content as raw CSS text

Rules:

- The first non-blank line inside a `layout` block MUST be `---`.
- The YAML front matter MUST be terminated by a second `---`.
- Layout YAML MUST parse to a mapping object.
- CSS style text is everything after the closing `---`, including newlines.

Common layout keys:

- `stylesheets`: array of stylesheet URLs
- `container_class`: wrapper class for screen HTML
- `style`: populated from trailing CSS text (not authored directly in YAML)

## 6. Markdown Dialect and Extensions

The initial ruby Documark implementation uses the Kramdown library and supports all of its extensions. As the format matures, it is possible that Documark will develop its own patterns for extension, possibly replacing the Kramdown patterns.

While you may use anything valid for Kramdown in your Markdown sections, it is possible that these won't be compatible with a future revision. If you want documents to safely upgrade if there is major change as Documark matures, stick to the official markdown specification <https://daringfireball.net/projects/markdown/syntax>, plus widely adapted extensions like GFM tables.

## 7. Validation and Errors

Implementations MUST reject or fail in these cases:

- file is empty
- first line is not a valid Documark header with context `documark`
- unterminated `data` or `layout` block
- malformed layout block delimiters
- layout front matter is not a mapping

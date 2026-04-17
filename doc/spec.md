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
- Parsed YAML MUST be a mapping object.

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

The initial Ruby Documark implementation uses the Kramdown library as its Markdown engine.

Documark defines its own extension syntax for applying classes, IDs, data attributes, and semantic HTML elements to document content (see sections 8.1, 8.2, and 8.4). These replace the need for Kramdown's block attribute extension (`{: .class }`). The Kramdown extension syntax is unsupported in Documark — it is not part of the Documark standard and its behaviour in future implementations is not guaranteed. It may incidentally work in the current implementation because Kramdown is the underlying engine, but documents relying on it will not be portable.

For maximum forward compatibility, the body of a Documark document SHOULD use:

- The core Markdown specification: <https://daringfireball.net/projects/markdown/syntax>
- Widely adopted extensions such as GFM tables and fenced code blocks
- Documark's own `@{}`, `@<>`, and `@[]` tag syntax for styling and semantic structure

### 6.1 Style Recommendations

These are recommendations, not format rules. They are intended to improve readability, portability, and consistency across Documark documents.

**Prefer `*` over `_` for emphasis and bold.**  Markdown permits both `*italic*` and `_italic_`, and both `**bold**` and `__bold__`. In Documark, `_` is strongly associated with underline in the minds of many readers and writers — even though Markdown does not implement underline. To avoid visual confusion, authors SHOULD use `*` and `**` for italic and bold respectively.

**Combine `@{}` with Markdown emphasis rather than using `@<b>` or `@<i>`.**  When a styled emphasis span is needed, the preferred form is:

```text
@{ .classname }**bold text**@{}
@{ .classname }*italic text*@{}
```

This keeps Markdown's own constructs intact, simplifies export, and avoids reliance on `@<>` for elements Markdown already handles.

## 7. Validation and Errors

Implementations MUST reject or fail in these cases:

- file is empty
- first line is not a valid Documark header with context `documark`
- unterminated `data` or `layout` block
- malformed layout block delimiters
- layout front matter is not a mapping

## 8. In-Document Tag Syntax

Documark reserves the `@` prefix combined with a brace-like delimiter for within-document directives. These controls are distinct from `!!` directives, which are document-level structure only.

The four reserved sigil families are:

| Sigil | Purpose |
|-------|---------|
| `@{ }` | Block attribute and inline span tags (classes, IDs, data attributes) |
| `@[ ]` | Semantic block element directives |
| `@< >` | Inline HTML element directives |
| `@( )` | Reserved — purpose not yet defined |

These forms are visually distinctive in plain text and form a uniform family that is straightforward to target with editor syntax highlighting rules.

### 8.1 `@{}` — Block Attribute and Inline Span Tags

`@{}` applies CSS classes, element IDs, and `data-*` attributes to Markdown content. It has three scope modes determined by position.

#### Supported attributes

| Notation | Output |
|----------|--------|
| `.classname` | Added to `class="..."` |
| `#identifier` | Sets `id="..."` |
| `data-key="value"` | Sets `data-key="value"` (quoted) |
| `data-key=value` | Sets `data-key="value"` (unquoted shorthand) |

`style=` inline values are NOT supported. Use CSS classes.

ARIA attributes are NOT supported as authored attributes. Semantic elements (section 8.2) carry implicit ARIA roles. Cases requiring explicit ARIA are handled via pass-through HTML.

#### Single-block form

`@{ }` on its own line with content immediately following (no blank line between) wraps the next Markdown block in a `<div>`.

```text
@{ .chapter-intro }
This paragraph is wrapped in a div with class "chapter-intro".

The next paragraph is not wrapped.
```

Rules:

- The tag line MUST contain only the `@{ }` directive and nothing else.
- There MUST be no blank line between the tag line and the first line of the block.
- Only the immediately following block (up to the next blank line) is wrapped.
- Output element is `<div>`.

#### Section form

`@{ }` on its own line with a blank line immediately following opens a section that wraps all content until an empty close marker `@{}`.

```text
@{ .warning }

First paragraph inside the section.

Second paragraph also inside.

@{}
```

Rules:

- There MUST be a blank line between the tag line and the first content line.
- The close marker is `@{}` (the `@{}` form with empty content) on its own line.
- Everything between open and close is rendered as Markdown and wrapped in `<div>`.
- Output element is `<div>`.

#### Inline span form

`@{ }` appearing within a line of text (not on its own line) applies a `<span>` to inline content.

```text
This sentence has @{ .highlight } one word highlighted.

This sentence has @{ .highlight } several highlighted words @{} and then normal text.
```

Rules:

- If no close marker `@{}` is present before the end of the block, the tag applies to the **next word only**.
- If `@{}` (empty close) is encountered before end-of-block, the span covers content between open and close.
- Output element is `<span>`.

---

### 8.2 `@[]` — Semantic Element Directives

`@[]` introduces HTML5 semantic elements that have no direct Markdown equivalent: `aside`, `section`, `article`, `figure`, `figcaption`, `header`, `footer`, and others.

The distinction from `@{}` is intentional:

- `@{}` is a styling and attribute overlay; it always outputs `<div>` or `<span>`.
- `@[]` is structural; it outputs the named HTML element.

`@[]` accepts the same attribute notation as `@{}`: `.class`, `#id`, `data-*`.

The element name in `@[]` is not validated against a whitelist. Unknown element names pass through to the HTML output; browsers ignore elements they do not recognise.

#### Single-block form

`@[element]` on its own line with content immediately following (no blank line between) wraps the next block in the named element.

```text
@[aside .literary-note]
This paragraph becomes the content of an aside element.

The next paragraph is outside the aside.
```

Rules:

- No blank line between the tag line and the first line of the block.
- Only the immediately following block is wrapped.
- No close marker required for single-block form.

#### Section form

`@[element]` on its own line with a blank line immediately following opens a section closed by `@[/element]`.

```text
@[aside .note]

First paragraph inside the aside.

Second paragraph also inside.

@[/aside]
```

Rules:

- There MUST be a blank line between the tag line and the first content line.
- The close marker is `@[/element]` where `element` matches the opening element name exactly.
- A mismatched close marker (e.g. `@[/article]` inside an `@[aside]` section) is treated as content, not as a close.
- Everything between open and close is rendered as Markdown inside the named element.

#### Inline use

`@[]` does not have an inline form. Markdown's own syntax covers inline semantic elements (`*em*`, `**strong**`, `` `code` ``). Using Markdown's native forms is preferred because it keeps `.dm` files cleanly extractable to plain Markdown.

---

### 8.3 Namespace Reservation

`@()` is reserved and MUST NOT be used in documents. Its purpose is not yet defined. Implementations MAY warn on encountering this form and SHOULD pass it through as literal text.

### 8.4 `@<>` — Inline Element Directives

`@<>` introduces inline HTML elements that have no Markdown equivalent: `<u>`, `<abbr>`, `<cite>`, `<kbd>`, `<mark>`, `<del>`, `<ins>`, `<sub>`, `<sup>`, and others. The angle-bracket sigil visually echoes HTML and signals that this is a named HTML element rather than a CSS class overlay.

The taxonomy of in-document tag forms is:

| Sigil | Output | Scope |
|-------|--------|-------|
| `@{}` | `<div>` or `<span>` | block, section, or inline — styling overlay |
| `@[]` | named block-level element | block or section |
| `@<>` | named inline element | inline only |

`@<>` accepts the same attribute notation as `@{}` and `@[]`: `.class`, `#id`, `data-*`.

#### Closure rules

`@<>` follows the same rules as the inline span form of `@{}`: scope is determined by whether an explicit close is present.

```text
This is @<u> underlined @</u> text.

This is @<u> word only (unterminated, applies to next word).
```

- If an explicit close `@</element>` is present, the span covers all content between open and close.
- If no close is encountered before end-of-block, the directive applies to the **next word only**.
- `@<>` MUST NOT be used in block or section position (on its own line). It is inline-only.

#### Elements with Markdown equivalents

`@<>` is intended for inline HTML elements that Markdown cannot express. It SHOULD NOT be used for elements that Markdown already handles natively: `b`, `i`, `strong`, `em`, `code`, `s`, `strike`.

When combining a CSS class with a Markdown-native emphasis element, use `@{}` inline span syntax and embed the Markdown notation inside it:

```text
@{ .prismatic }**Shimmering**@{}
```

This renders as `<span class="prismatic"><strong>Shimmering</strong></span>` and round-trips cleanly to plain Markdown by stripping the span wrapper and preserving the `**Shimmering**` content. By contrast, `@<b .prismatic>Shimmering@</b>` would require semantic knowledge of which HTML elements are Markdown-equivalent to export correctly, and is therefore non-preferred.

#### Recommended usage: underline

Markdown has no underline syntax. `@<u>` is the Documark idiomatic form:

```text
This word is @<u> underlined @</u> in the output.
```

Authors should be aware that underline is strongly associated with hyperlinks in screen rendering. Using `@<u>` for decorative emphasis in screen output may confuse readers. CSS `@media print` rules can be used to apply underline in print contexts only.

`@<ins>` is available as a semantically richer alternative when the intent is to mark inserted or added text (rendered as underline by browsers by default).

#### Export and round-trip behaviour

When a Documark document is rendered back to plain Markdown or another format that does not support those inline HTML elements natively, `@<>` directives SHOULD be stripped — the enclosed text is preserved, the element wrapper is discarded. Implementations MAY offer an option to emit the directives as raw inline HTML instead, but this reference implementation does not provide that option.

### 8.5 Escaping Tag-Like Content

To include literal text that would otherwise be recognised as a Documark tag, prefix the `@` with a backslash: `\@`. Additionally the `!!` sequence at the beginning of a line should be escaped.

```text
\@{ .green }
\@[aside]
\@[/aside]
\!!
```

The backslash escape is consistent with Markdown's own escape convention (`\*`, `\#`, etc.), which authors already know.

Rules:

- A `\@` sequence at the start of a line (after stripping leading whitespace) MUST be treated as literal text, not as a tag directive.
- A `\@` sequence within a line MUST be treated as a literal `@`.
- The leading backslash is consumed by the processor and MUST NOT appear in the output.
- Escaping applies to all `@`-sigil forms: `\@{}`, `\@[]`, `\@()`, `\@<>`.
- A `\!!` at the start of a body line prevents the `!!` from being misread as a directive; the backslash is handled by the Markdown engine (which treats `\!` as a literal `!`) — no special Documark processor handling is required.
- A backslash not immediately followed by `@` is passed through unchanged and handled by the Markdown engine according to its own escape rules.

It is strongly recommended that document authors escape any `@`-sigil-like text that appears in running prose or headings and is not intended as a directive — for example when describing Documark syntax within a Documark document. Processors are not required to detect or reject unescaped tag-like text that appears in non-directive positions; behaviour in such cases is not defined.


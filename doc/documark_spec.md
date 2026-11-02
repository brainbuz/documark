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
- `assets`

Blank lines between major sections are allowed.

The `assets` block is a special top-level section, not an ordinary named block: when present it MUST be the last section in the file, and nothing but blank lines may follow its `!! end`. Rather than plain-text content it carries a packed archive of the document's (or layout's) supporting files. See section 11 for the wire format and the `pack`/`unpack` CLI actions that produce and consume it. Known caveat: the processor locates the body/assets boundary by scanning for the first column-0 line matching the `!! assets` header form, so a literal `!! assets` line at column 0 inside a body code fence will falsely trigger that boundary; see section 10.3 — this is a documented, accepted limitation rather than a bug slated for a fix.

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
- `requires`: array of feature names this document depends on (section 9). The processor MUST verify every listed feature is loaded before tag processing begins; missing features cause a hard error.

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
- `toc`: configuration for the `@(toc)` directive (section 5.2)
- `index`: configuration for the `@(index)` directive (section 5.2)
- `requires`: array of feature names the layout depends on (section 9). Unioned with the document's `requires` list and validated together.

### 5.2 TOC and Index Layout Keys

The `toc` and `index` layout keys configure the corresponding `@()` directives (section 8.3). All sub-keys are optional.

#### `toc`

| Sub-key | Type | Default | Effect |
|---------|------|---------|--------|
| `depth` | integer | `3` | Maximum heading level included (`1..depth`) |
| `title` | string | _none_ | Title rendered as `<h2 class="toc-title">` above the list |
| `style` | string | _none_ | When set to `css`, suppresses the default print CSS so the layout stylesheet handles TOC page numbers itself |

#### `index`

| Sub-key | Type | Default | Effect |
|---------|------|---------|--------|
| `title` | string | _none_ | Title rendered as `<h2 class="index-title">` above the list |
| `limit_entry_per_page` | boolean | `false` | When `true`, after the initial PDF render the index is rewritten to drop consecutive same-page entries within each term, and a second render is performed |
| `classes` | mapping | _empty_ | CSS classes appended to the built-ins on each index element; recognized sub-keys are `nav`, `title`, `dl`, `dt`, `dd` |
| `style` | string | _none_ | When set to `css`, suppresses the default print CSS so the layout stylesheet handles index page numbers itself |

`limit_entry_per_page` only affects PDF output, since page numbers are only defined for print targets. It has no effect on HTML, Markdown, or text output.

## 6. Markdown Dialect and Extensions

The initial Ruby Documark implementation uses the Kramdown library as its Markdown engine.

Documark defines its own extension syntax for applying classes, IDs, data attributes, and semantic HTML elements to document content (see sections 8.1, 8.2, and 8.4). These replace the need for Kramdown's block attribute extension (`{: .class }`). The Kramdown extension syntax is unsupported in Documark — it is not part of the Documark standard and its behaviour in future implementations is not guaranteed. It may incidentally work in the current implementation because Kramdown is the underlying engine, but documents relying on it will not be portable.

For maximum forward compatibility, the body of a Documark document SHOULD use:

- The core Markdown specification: <https://daringfireball.net/projects/markdown/syntax>
- Widely adopted extensions such as GFM tables and fenced code blocks
- Documark's own `@{}`, `@<>`, and `@[]` tag syntax for styling and semantic structure

### 6.1 Markdown Extension Lineage

Understanding where GFM's extensions come from is useful context for what "widely adopted" means in practice.

The original Markdown specification (John Gruber, 2004) defined core inline and block constructs but deliberately left many document features unspecified. Several independent projects extended it:

**PHP Markdown Extra** (Michel Fortin, ~2004) introduced tables, definition lists, footnotes, fenced code blocks (using `~~~`), and inline attribute syntax. Many later Markdown processors, including Kramdown, credit PHP Markdown Extra as the source for these features.

**CommonMark** (John MacFarlane et al., 2014–) is a formal specification that resolves ambiguities in the original Markdown spec. It defines precise parsing rules for the core feature set but does not standardize extensions. CommonMark is the best available reference for what portable baseline Markdown means.

**GitHub Flavored Markdown (GFM)** (GitHub, 2017–) is a CommonMark superset. It standardizes tables (adapted from PHP Markdown Extra), fenced code blocks with backtick syntax, strikethrough, task lists, and autolinks. GFM is the de facto standard for the extension layer because of GitHub's ubiquity.

When this document says "GFM tables and fenced code blocks," it means these features as widely understood across tools — not a strict conformance requirement against the GFM specification document.

### 6.2 Style Recommendations

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
| `@( )` | Documark directives — table of contents, index, includes |

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

### 8.3 `@()` — Documark Directives

`@()` introduces processor-level directives. Unlike `@{}` / `@[]` / `@<>`, which produce HTML elements, `@()` requests structural document features.

#### Grammar

Every `@()` directive has one of two forms:

```
@( <name> [args...] )                       single-line
@( <name> [args...] begin ) ... @( end )    block
```

- `<name>` is a lowercase identifier matching `[a-z][a-z0-9-]*` — the first word inside the parens.
- `[args...]` is an opaque argument string between the name and `)` or `begin )`. Quoting is not required by the parser; directive handlers parse args themselves.
- For the block form, all content between the opener and the matching `@( end )` is collected verbatim — no inline processing — and passed to the handler as the **content** argument.
- `@( end )` is always literal `end`, never named; it closes the most recent unclosed block opener. Matching is depth-aware: nested `@( x ... begin )` / `@( end )` pairs of the same directive shape increment and decrement an internal depth counter as they are scanned, so an `@( end )` only terminates the block once every nested opener of the same shape inside it has already been closed — it is not simply "the next `@( end )` seen."

Unknown directive names are a hard error. Calling a block-only directive in single-line form (or vice versa) is also a hard error.

#### Defined directives

| Form | Effect |
|------|--------|
| `@(toc)` | Emit a table of contents at this point |
| `@(index)` | Emit a sorted index of registered terms at this point |
| `@( include path )` | Splice the contents of another file in at this point. Path may be bare (no whitespace, no quotes, no `)`), single-quoted, or double-quoted. |
| `@( include path type )` | Same, with explicit type. Built-in types are `markdown`, `html`, `text`; plugins may extend `include` with additional types (section 9). |
| `@(# term)` | Inline only. Register `term` in the index with an anchor at this location |
| `@# word` | Inline only. Shorthand for `@(# word)` where the term is a single letter-only word; also wraps the word in the anchor |
| `@( if CONDITION begin )` ... [`@( else )`] ... `@( end )` | Conditionally include the true or else branch based on a condition evaluated against document `data` |
| `@( name begin )` ... `@( end )` | Block directive — plugin- or core-handled raw content block |

A line that starts with `@( include` but doesn't match the directive grammar (e.g. unquoted path with whitespace, mismatched quotes) is a hard error rather than silently passing through as literal text.

#### Block directives: `@( name args begin )` / `@( end )`

Block directives open and close raw content blocks. Unlike `@( include )`, the content is written inline in the document body rather than in a separate file. The preprocessor collects every line between the opener and the closer verbatim — without running Documark's inline tag processor — and passes the collected text as a single string to the handler.

Rules:

- The closer is always `@( end )`, regardless of the directive name.
- An opener with no registered handler is a hard error.
- A `@( end )` with no preceding opener is a hard error.
- An unterminated opener (no closer before end of file) emits a warning and the remaining document body is treated as block content.
- Content between the markers is raw and not subject to Documark tag processing.
- The opener/closer scan is depth-aware (see the note on `@( end )` above): nested `@( x ... begin )` / `@( end )` pairs are correctly paired rather than the first `@( end )` closing the outermost opener. Known caveat: foreign block content shaped exactly like `@( x begin )` — for example a directive-shaped line quoted inside a `talltable`/`asciidoc` block's raw content — can still misfire the depth counter, since the scanner cannot tell "real" nested openers from lines that merely look like one; this is rare in practice and strictly better than the previous behavior, where the very first `@( end )` encountered closed the block regardless of nesting (section 10.2).

**Currently registered block directives: `asciidoc`, `talltable`**

Provided by the `asciidoc` plugin (section 9.7). Renders the block content as AsciiDoc via Asciidoctor, then strips Asciidoctor structural CSS classes (preserving `language-*` on code elements). The primary use case is tables with multi-line cells, colspan/rowspan, or complex headers — things GFM pipe-table syntax cannot express.

```text
@(asciidoc begin)
|===
| Column A | Column B | Column C

| Cell with *bold* text
and a second line

| Simple cell
| Another

| Row 2A | Row 2B | Row 2C
|===
@( end )
```

A document using this directive SHOULD declare `requires: [asciidoc]` in its data block.

#### `@(toc)` — Table of contents

Emits a `<nav id="toc">` containing a Kramdown-generated list of headings from the document. The depth (which heading levels are included) and an optional title are controlled by the `toc` layout key (section 5.2). For print targets, page numbers are added to each TOC entry via WeasyPrint's `target-counter`.

Only one `@(toc)` directive per document; a second occurrence is a hard error.

#### `@(index)` — Document index

Emits a `<nav id="index">` containing a `<dl>` of registered index terms (alphabetical, case-insensitive) and links to each occurrence. For print targets, page numbers are added to each link via WeasyPrint's `target-counter`. If no entries are registered, nothing is emitted.

Behavior is controlled by the `index` layout key (section 5.2), including the optional title, CSS classes, and `limit_entry_per_page` (which drops consecutive same-page entries within a term during a second-pass render).

Only one `@(index)` directive per document; a second occurrence is a hard error.

#### `@(# term)` and `@# word` — Index registration

Both forms register an index term and emit an anchor at the call site.

- **Full form `@(# term)`** — The term may contain any characters except `)`. The anchor is empty (it does not wrap surrounding text).
- **Shorthand `@# word`** — The word is one or more Unicode letters (`\p{L}+`); any non-letter character terminates the word. The anchor wraps the matched word in `<a>`. Authors who need digits, punctuation, or symbols inside a term MUST use the full form.

Multiple registrations of the same term are grouped under one entry in the rendered index, in document order.

#### `@( include path [type] )` — File inclusion

Reads the named file and splices its content in at this point, as if it had been typed there. All paths resolve relative to the root document's directory. There is no path scoping per included file — nested includes that need a different base must use absolute paths. The path may be:

- **bare** — any run of characters containing no whitespace, no quotes, and no `)`. Convenient for simple filenames.
- **single-quoted** — `'path with spaces or special chars'`.
- **double-quoted** — `"path"`.

The optional second token forces a type interpretation:

- `markdown` (auto-detected for `.md` / `.markdown`) — content is spliced into the document at the include point and processed in the same pass, exactly as if it had been typed there. `@()` directives in the included content resolve normally.
- `html` (auto-detected for `.html`) — content is injected as raw HTML.
- `text` (auto-detected for any extension not claimed by a built-in or plugin) — content is emitted as a fenced code block.
- Plugin-registered types (e.g. `asciidoc`) — the plugin's converter renders the file to HTML, which is injected as raw HTML.

Hard-fail rules:

- An explicit type token that names a type no built-in handles and no loaded plugin provides is a hard error naming the missing feature.
- A bare include with an extension that doesn't match a known type falls back to `text` (so plain text files included without an explicit type still work).

An included Markdown file shares index/TOC state with its parent: terms registered inside an included file appear in the parent's `@(index)`, and headings inside it appear in the parent's `@(toc)`.

#### `@( if CONDITION begin )` / `@( else )` / `@( end )` — Conditional content

Includes or excludes a span of document content depending on a condition evaluated against the document's `data` (the document's `data` block merged with any `--define` overrides). Grammar:

```text
@( if CONDITION begin )
... kept when CONDITION is true ...
@( else )
... kept when CONDITION is false ...
@( end )
```

`@( else )` is optional; when it is absent, a false condition simply produces no output for the block.

Condition grammar — there are no boolean combinators (no `and`/`or`/parentheses); a condition is exactly one of:

- `NAME` — truthy test on `data[NAME]`.
- `!NAME` — negated truthy test.
- `NAME=VALUE` — string equality. `VALUE` is everything after the first `=`, stripped, with one pair of matching surrounding quotes (`'...'` or `"..."`) removed if present; `VALUE` may be empty.

`NAME` MUST match `[A-Za-z_][A-Za-z0-9_-]*` and refers to a top-level `data` key only — dotted or nested paths are not supported.

Truthiness: a value is falsy if and only if it is missing (the key is absent from `data`), `nil`, `false`, an empty string (after stripping), or the string `"false"` compared case-insensitively. Every other value — including `0`, `"0"`, arrays, and hashes — is truthy.

Equality: `NAME=VALUE` compares `data[NAME].to_s` (not stripped) against the literal `VALUE`. A missing key is always false, regardless of `VALUE`.

`@( else )` and nesting rules:

- `@( else )` splits the block at depth 0 only; an `@( else )` belonging to a nested `@( if ... begin )` is transparent to the split and stays with its own inner block.
- A second depth-0 `@( else )` inside the same `if` block is a hard error.
- An `@( else )` with no enclosing `@( if ... begin )` is a hard error.
- An `if` nested inside a kept branch is reprocessed normally: inline tags (`@{}`, `@[]`, `@<>`) and nested directives inside the kept branch resolve exactly as if that branch had been typed directly into the document body.

`@( if )` behaves uniformly across every output target, though two different code paths implement it:

- For `html` and `pdf`, the built-in `if` directive is dispatched through the same depth-aware block-directive scanning described above, via `TagProcessor`'s `_scan_raw_block`.
- For `markdown` and `text`, which do not go through `TagProcessor` at all, a standalone recursive pass (`Documark::Conditionals.resolve`) walks the raw document body before export, resolving `@( if )` blocks the same way and passing every other `@( x begin ) ... @( end )` block through untouched and uninterpreted, leaving it for the usual markdown/text cleanup pass to handle.

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

## 9. Features and Plugins

Documark functionality is organized into named **features**. A feature is the unit of dependency declaration in a document or layout: `requires: [feature_name]` in either YAML block states that the document cannot be processed without the named feature loaded.

Built-in features ship with every conforming implementation. Additional features may be provided by **plugins** — independent Ruby files (typically distributed as separate gems) that register themselves into the running implementation at startup.

### 9.1 Feature Naming

Feature names match `[a-z][a-z0-9-]*`: lowercase ASCII, hyphens allowed, must begin with a letter. The same naming rule applies to include type tokens, directive names, and target names; in practice a feature usually shares a name with its primary capability.

### 9.2 Built-in Features

Conforming implementations MUST register the following features at startup:

| Feature | Provides |
|---------|----------|
| `markdown` | Markdown include type, `markdown` output target |
| `html` | HTML include type, `html` output target |
| `text` | Plain text include type, `text` output target |
| `pdf` | `pdf` output target |
| `epub` | `epub` output target (may be a stub) |
| `toc` | The `@(toc)` directive |
| `index` | The `@(index)` directive |
| `include` | The `@( include )` directive |
| `if` | The `@( if ... begin )` / `@( else )` / `@( end )` conditional block directive |
| `container` | No directive of its own; gates `requires: [container]` for documents or layouts that rely on packed `.dmc`/`.dms` container files (section 11) |

Authors MAY name any of these in `requires:` but typically omit them by convention, since they are present in every conforming implementation. An alternative implementation targeting constrained environments MAY load handlers lazily based on the declared `requires:` list, in which case exhaustive declaration becomes useful.

### 9.3 The `requires:` Key

`requires:` is an optional YAML key in the document `data` block (section 4.1) and/or the layout's YAML front matter (section 5.1). Its value is an array of feature names.

Rules:

- The processor MUST union the `requires:` arrays from the document and the layout and verify every feature name is registered before tag processing begins.
- A missing feature is a hard error. The error message MUST name every missing feature and identify the source file declaring the requirement.
- Empty/missing `requires:` is a no-op.

Example:

```yaml
title: "Quarterly Report"
language: en
requires:
  - asciidoc
  - pdf
```

A document that uses `@( include 'foo.adoc' )` SHOULD declare `requires: [asciidoc]` so that environments without the AsciiDoc plugin fail fast with a clear message rather than at the point of include.

### 9.4 Capability Kinds

Plugins extend Documark by registering capabilities. Each capability links back to a named feature so that loading the feature is sufficient to activate the capability. See `doc/plugin_authoring.md` for the practical authoring API.

- **Directive** — handles a new `@(name args)` or `@(name args begin)...@(end)` form. The handler receives the args string, the block content (or nil), and a context object exposing preprocessor state. It returns `{ html:, mode: }` where mode is `:placeholder` (wrap in placeholder, invisible to Kramdown) or `:passthrough` (splice into the markdown stream).
- **Include-type contribution** — extends the built-in `@( include )` directive with a converter for a new file type, optionally claiming file extensions for auto-detection. The converter receives the file content and returns the same `{ html:, mode: }` shape as a directive handler.
- **Output target** — handles a new `-t <name>` argument. Built-in targets register here too so that target validation is uniform.

Capabilities not registered (and not built-in) result in a hard error at the point of use.

### 9.5 Discovery and Loading

A plugin is a Ruby file located at `lib/documark/plugin/<name>.rb` in any directory on the load path — whether shipped in this repository, in a separately installed gem, or in a directory placed on the load path manually.

Conforming implementations of the Ruby reference processor SHOULD use `Gem.find_files('documark/plugin/*.rb')` (or equivalent) to discover plugins at startup. An alternative implementation MAY use a different discovery mechanism (a manifest file, a `--plugin` flag, lazy loading driven by `requires:`) as long as the externally observable behavior is consistent: presence of a plugin makes its features available; absence with a `requires:` reference fails up-front.

### 9.6 Plugin Load Failure Policy

If a plugin file is present and discovery attempts to load it, the load MUST complete successfully or the entire Documark invocation MUST fail with a clear error that names the plugin and the underlying cause (missing dependency, syntax error, etc.).

There is no soft-fail or "skip and warn" path. The contract is: a plugin loads with all of its abilities, or it does not load and the user is told why. A user who does not want a plugin's third-party dependencies should not install the plugin file.

This applies to:

- Missing Ruby gems the plugin depends on.
- Syntax or load-time errors in the plugin file.

Discovery finding zero plugin files (no plugin gems installed) is normal and not an error.

### 9.7 Reference Implementation: AsciiDoc Plugin

This repository includes the reference plugin at `plugins/asciidoc/lib/documark/plugin/asciidoc.rb`, packaged as the separate `documark-plugin-asciidoc` gem. When installed and loaded, it registers two features:

**Feature `asciidoc`:**

- Contributes an include type `asciidoc` claiming the `.adoc` and `.asciidoc` extensions, enabling `@( include 'file.adoc' )` and `@( include 'file.txt' asciidoc )`.
- Registers the `asciidoc` block directive, enabling `@( asciidoc begin )` ... `@( end )` in document bodies.
- Both capabilities convert AsciiDoc source to HTML via the `asciidoctor` gem, stripping CSS classes added by AsciiDoctor while preserving `language-*` classes on `<code>` and `<pre>` elements (so syntax highlighting hooks still work).

**Feature `talltable`:**

- Registers the `talltable` block directive — currently a semantic alias for `@( asciidoc begin )`. Reserved for future enhancement to a more table-specific syntax (see `todo.txt`).
- Primary use case: tables with multi-line cell content, colspan/rowspan, or complex headers that GFM pipe-table syntax cannot express.

This plugin requires the `asciidoctor` and `nokogiri` gems; per section 9.6, those are mandatory if the plugin file is installed.

## 10. Known Issues

These are areas where current implementation behavior is not committed to the spec and is likely to change.

### 10.1 In-Document Tags Inside Markdown Code Regions

Documark's preprocessor currently scans tag syntax (`@{}`, `@[]`, `@<>`, `@()`) without regard to Markdown code spans (`` `...` ``) or fenced code blocks (```` ``` ````). Tag-like text inside code regions is processed as if it were running prose.

This is undesirable: authors documenting Documark syntax inside a Documark document must escape every example with `\@`, even inside a code fence where the intent is plainly literal text.

The likely future behaviour is for the preprocessor to recognise Markdown code spans and fences and skip them. Authors should for the present consider the behaviour of @tags in these regions to be undefined.

### 10.2 Block Directive Depth Counter Can Misfire on Foreign Content

The depth-aware scanning that pairs `@( x ... begin )` with its matching `@( end )` (section 8.3) works by counting any stripped line that matches the block-opener or `@( end )` shape, regardless of which directive is actually active. Foreign block content — for example raw AsciiDoc or another directive's raw content — that happens to contain a line shaped exactly like `@( something begin )` or `@( end )` will still increment or decrement the counter, even though it is not a real nested Documark block. This is rare in practice, and is strictly better than the previous implementation, where the very first `@( end )` encountered closed the outermost opener regardless of nesting. There is no plan to fix this beyond documenting it; authors embedding raw content that could contain such a line should be aware of it.

### 10.3 `!! assets` Boundary Detection Inside Body Code Fences

The parser locates the start of a document's trailing `!! assets` section (section 3.2, section 11) by scanning for the first line, at column 0, that parses as an `!! assets` header. It does not distinguish a real section boundary from a literal `!! assets` line that happens to appear at column 0 inside a body code fence (for example, a fenced example showing Documark's own container format). Such a line will falsely trigger the body/assets boundary, truncating the body early and misinterpreting whatever follows as the assets archive. This is a documented, accepted limitation, not a bug to be fixed; authors documenting Documark's own syntax should indent or otherwise avoid a column-0 `!! assets` line inside a body code fence.

## 11. Container Format

A Documark **container** bundles an ordinary document (or layout) file together with the local files it depends on — images, stylesheets, includes — into a single, still-readable file. Nothing about the document's own text sections changes; a container is a document with one extra section appended at the end.

### 11.1 Wire Format

A container is the document's ordinary content — header, `data`, `layout`, and body sections exactly as sections 3 through 6 define them — followed by a top-level `assets` block:

```text
!! assets
<base64 of a gzipped POSIX tar archive>
!! end
```

Per section 3.2, this `assets` block MUST be the last section in the file; nothing but blank lines may follow its `!! end`. Text sections are never touched by packing — they remain plain-text and readable even in a packed file; only the supporting files travel as an opaque archive.

### 11.2 Path Validation (Security Boundary)

Every path referenced inside the archive — on both pack (encoding) and unpack (decoding) — MUST pass the same validation, which is the security boundary against path traversal and absolute-path writes: relative (no leading `/`), `/`-separated with no backslashes, no `.` or `..` path segments and no empty segments (so `a//b` and `a/` are both rejected), and no NUL bytes. Because this validation runs on both the encode and decode paths, a hostile or malformed archive — one with a `../../etc/passwd`-style entry, for instance — cannot be produced by `pack` in the first place, and if such an archive were somehow constructed by hand, `unpack` refuses it rather than writing outside the destination directory.

### 11.3 Asset Discovery When Packing

When packing a document, Documark discovers its local supporting files by scanning `@( include ... )` directive arguments in the body, Markdown image references (`![alt](path)`), the layout's `stylesheets` entries, `url(...)` references inside the layout's `style` CSS text, and one level of recursion into any discovered local `.css` file so that file's own `url(...)` references (for example, `@font-face` font files) are picked up too. References that are URLs (`http:`, `https:`, or any other URI scheme), `data:` URIs, `mailto:` links, fragment-only references (`#...`), or absolute paths are skipped — only relative, local, on-disk files are candidates. A discovered reference to a file that doesn't exist on disk produces a warning and is skipped rather than failing the pack.

### 11.4 Per-Target Extraction

When `process` runs against a container (or a document paired with a stationery/layout container — section 12), assets are extracted differently depending on the output target: **`html`** extracts beside the output file and leaves the extracted files there after the run completes, so the rendered page's relative asset references keep working afterward; **`pdf`/`epub`** extract into a temporary directory that WeasyPrint is pointed at via `--base-url`, then removed once rendering finishes; **`markdown`/`text`** extract nothing, since these targets emit raw body text and have no notion of a base URL for relative assets.

### 11.5 CLI

```sh
bundle exec bin/documark pack --input mydoc.dm --output mydoc.dmc
bundle exec bin/documark unpack --input mydoc.dmc --output mydoc-unpacked/
```

`pack` reads `--input`, discovers its assets, and writes a container to `--output`. Packing a file that is already a container (it already has an `!! assets` section) is a hard error — unpack it first. `unpack` reads a container at `--input`, writes its document (minus the `assets` section, with a `.dml` extension if the original declared `type=layout` and `.dm` otherwise) plus its extracted asset tree into the `--output` directory. Unpacking a file with no `!! assets` section is a hard error.

## 12. Stationery

**Stationery** is not a new file format — it is simply the name for an external layout file (conventionally given a `.dms` extension) that also carries a trailing `!! assets` section. There is no special stationery header or block; a stationery file still begins with the ordinary layout header (`!! documark layout`) described in section 5, and becomes a stationery file purely by having `pack` (section 11) applied to a `.dml` file.

### 12.1 The `--layout` Option

`--layout <file>` names a layout or stationery file to use for a `process` run, overriding the `default_layout` value from config. Precedence, most specific first:

1. An embedded document `layout` block (section 5) — if the document itself carries a `layout` section, it always wins over `--layout` and `default_layout`, and it carries no assets of its own; assets only ever come from an *external* layout file.
2. `--layout` (or the config file's equivalent).
3. `default_layout` from config.
4. The built-in default layout template.

### 12.2 Asset Extraction Ordering

A `process` run can pull assets from two sources at once: the resolved stationery/layout file (if it is itself a container) and the document's own `!! assets` section (if the document itself is a container). Both extract into the same destination directory — stationery assets first, then the document's assets. On a filename collision between the two, the document's copy is what ends up on disk, since it is written second. Per-target extraction semantics are identical to section 11.4 (`html` beside the output and left in place, `pdf`/`epub` to a cleaned-up temporary directory, `markdown`/`text` none).

### 12.3 Packing a Layout File

`pack` also works on a layout-type file (one whose header is `!! documark layout`). Since a layout file has no document body to scan, asset discovery for a layout-type pack considers only layout sources: `stylesheets` entries, `url(...)` references in the `style` CSS text, and the same one-level `.css`-file recursion described in section 11.3. The resulting `.dms` file is read back exactly like any other layout file — via `--layout`, `default_layout`, or the built-in default — its assets riding along automatically.


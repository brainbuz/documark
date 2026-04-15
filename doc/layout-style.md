# Documark Layout Style Guide

This document explains the `style` portion of a Documark layout.

In the current prototype, the `style` portion is the raw CSS that appears after the YAML front matter inside a `layout` block. It is not a side detail. It is the main mechanism for controlling page appearance, especially for print and PDF output.

## What The Style Section Is

A layout block has two parts:

1. YAML front matter
2. raw CSS

Example:

```text
!! layout
---
stylesheets:
  - "https://example.com/document-base.css"
container_class: container
---

@media screen {
  /* screen rules */
}

@media print {
  @page {
    size: letter portrait;
    margin: 1in;
  }
}
!! end
```

Everything after the second `---` is treated as CSS and injected into the generated HTML inside a `<style>` element.

## Why It Matters

The style section is where a Documark layout becomes a real document design rather than just a metadata wrapper.

It controls things like:

- print page size and margins
- base typography and spacing
- screen layout versus print layout
- interaction with any external stylesheets
- resets needed to avoid browser or framework defaults interfering with print output

In practice, the style section is the place where a template author defines the visual rules of the document.

## Relationship To Other Layout Fields

The current layout model has three important styling-related pieces:

- `stylesheets`: external CSS files to load first
- `container_class`: a wrapper class applied for screen HTML output
- `style`: inline CSS authored directly in the layout block

These are complementary, not interchangeable.

Typical pattern:

- use `stylesheets` to load a base CSS framework or shared theme
- use `container_class` to opt into a screen-oriented wrapper from that framework
- use the `style` section to define Documark-specific behavior, especially print rules

## Screen And Print

Documark is trying to support both browser viewing and printable output.

That makes `@media screen` and `@media print` especially important.

Typical responsibilities:

- `@media screen`: browser reading experience, responsive layout, preview behavior
- `@media print`: page geometry, print typography, margin handling, page break behavior

If a layout uses the same CSS for everything, it will usually be harder to get good print output.

## PDF Rendering And The Style Section

The current prototype renders PDF by printing generated HTML through a Chromium-compatible browser.

That means the style section directly affects PDF output.

Important implications:

- `@page` rules matter
- print-mode typography matters
- browser defaults matter unless you reset them
- framework spacing can interfere with page geometry if left unmanaged

The current implementation also omits `container_class` for PDF output. That is a practical decision: many container classes add horizontal padding that would stack on top of the margins already defined in `@page`.

## Recommended Responsibilities For The Style Section

At minimum, a good layout style section should usually define:

- print page size and margins
- the document's print typography baseline
- margin and padding resets for `html` and `body` in print mode
- any layout corrections needed when using an external CSS framework

Depending on the layout, it may also define:

- heading scale
- paragraph spacing
- code and table presentation
- image sizing
- page-break behavior for headings, tables, and figures

## Example Pattern

```css
@media screen {
  /* screen preview defaults */
}

@media print {
  body {
    font-family: Georgia, "Times New Roman", Times, serif;
    font-size: 11pt;
    line-height: 1.3;
    color: #000;
  }

  @page {
    size: letter portrait;
    margin: 1in;
  }

  html, body {
    margin: 0;
    padding: 0;
  }

  h1, h2, h3 {
    page-break-after: avoid;
  }

  p, li, blockquote {
    orphans: 3;
    widows: 3;
  }

  pre, blockquote, table, figure {
    page-break-inside: avoid;
  }

  a {
    color: #000;
    text-decoration: none;
  }
}
```

This pattern does three useful things:

- separates screen and print concerns
- sets page geometry explicitly
- avoids accidental extra spacing around the printed page

It also shows several common print directives:

- `font-family` using built-in serif families available on every browser platform
- `@page` for physical page size and margins
- `orphans` and `widows` to reduce awkward page breaks in paragraphs
- `page-break-after` and `page-break-inside` to keep headings and blocks together
- link styling that removes screen-oriented color treatment for print

If you want a sans-serif print document, `Arial, Helvetica, sans-serif` are common fonts that browsers may ship with.

## External Frameworks

Using a CSS framework is fine, but the style section is still where layout authors take control back from framework defaults.

For example, a framework may:

- assume screen reading rather than print
- set default margins or paddings that are inappropriate for paged output
- size text using variables or rem-based scales that need adjustment for print

The style section is the right place to override those defaults.

## Custom CSS

The stylesheets key in the front matter allows you to use your own css, which can be compiled from scss. You can certainly move all of the styling to your custom sheet, in wich case the style section can just be some blank lines.

## Related Documents

- [Specification](spec.md)
- [Implementation Notes](implementation.md)
- [Example Layout](examples/example_layout.dml)
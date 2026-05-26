!! documark document
!! data
---
title: "Documark Table Styles"
language: 'en'
requires:
  - asciidoc
---
!! end
!! layout
---

  stylesheets:
  - "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"

  container_class: container

---

/* Base table rules applied to every table in the document.
   Pico CSS provides sensible defaults; these additions make
   borders explicit and consistent across screen and print. */
table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  padding: 0.4em 0.75em;
  border: 1px solid #ccc;
  vertical-align: top;
}

thead th {
  background: #f0f0f0;
  font-weight: 600;
  text-align: left;
}

/* Per-table override pattern.
   @{ .wide-table } wraps a table in <div class="wide-table">,
   letting CSS target that specific table without touching others. */
.wide-table table {
  font-size: 0.9em;
  letter-spacing: 0.01em;
}

.wide-table thead th {
  background: #ddeeff;
}

/* Striped rows via wrapper class — Pico's role="grid" targets <table> directly
   and cannot be applied through @{}. nth-child is the portable alternative. */
.striped tbody tr:nth-child(even) { background: #f5f5f5; }

/* Column and row targeting — no class attributes on cells needed. */
.col-demo td:first-child { font-weight: 600; }
.col-demo td:last-child  { text-align: right; color: #555; }
.col-demo tbody tr:last-child td { border-top: 2px solid #888; }

@media print {
  table {
    page-break-inside: avoid;
  }
}

!! end

# Documark Table Styles

This document demonstrates the three ways tables appear in Documark documents and how to style them using CSS in the layout block.

## 1. Native GFM Table

The simplest form. Markdown pipe-table syntax, rendered by Kramdown. Use this for straightforward tabular data where all cell content fits on one line.

| Format | Authoring | Multi-line cells | Colspan |
|--------|-----------|-----------------|---------|
| GFM pipe table | Markdown | No | No |
| AsciiDoc table | AsciiDoc block | Yes | Yes |
| HTML table | Raw HTML | Yes | Yes |

The layout's global `table`, `th`, and `td` rules apply automatically — no extra markup needed.

## 2. GFM Table with a Wrapper Class

Wrapping a table in `@{ .classname }` places it inside a `<div class="classname">`. CSS selectors like `.classname table` can then target that specific table without affecting others. The wrapper div is the standard Documark technique for per-table style overrides.

This table uses `@{ .wide-table }`, which the layout defines to apply a lighter blue header background and slightly smaller font. An explicit `@{}` closes the section wrapper.

@{ .wide-table }

| Package | License | Last release | Notes |
|---------|---------|-------------|-------|
| Pico CSS | MIT | 2024 | Semantic HTML, no class pollution |
| Bootstrap | MIT | 2024 | Class-heavy; needs wrapper override |
| Sakura | MIT | 2023 | Single-file classless CSS |
| MVP.css | MIT | 2023 | Classless, print-friendly |

@{}

## 3. Tall Table — Multi-line Cell Content

GFM pipe tables cannot contain line breaks inside a cell. AsciiDoc table syntax can. Use `@(asciidoc begin)` / `@( end )` to embed an AsciiDoc table directly in the document body — no separate file required.

Each cell below spans multiple lines in the source. Asciidoctor's structural CSS classes (`tableblock`, `halign-left`, etc.) are stripped automatically; the result is bare semantic HTML that inherits the layout's table rules.

@(asciidoc begin)
|===
| Approach | When to use | Limitations

| *GFM pipe table*

Standard Markdown syntax.
Rendered by Kramdown.

| Simple tabular data.
All content fits on one line per cell.
No special plugin required.

| No multi-line cells.
No colspan or rowspan.
No cell-level formatting beyond inline Markdown.

| *AsciiDoc table*

Written inside an
`@(asciidoc begin)` block.
Rendered by Asciidoctor.

| Complex tables.
Cells need paragraphs, lists, or
code examples inside them.
Merged headers (colspan/rowspan).

| Requires the `asciidoc` plugin.
Document must declare
`requires: [asciidoc]`.

| *HTML table*

Raw HTML included via
`@( include 'table.html' )`.

| Maximum control.
Existing HTML table assets.

| Verbose to write by hand.
No Documark tag processing inside the include.
|===
@( end )

## 4. Colspan Header Table

AsciiDoc supports merged header cells using the `2+|` span notation. This creates a `colspan="2"` attribute on the resulting `<th>` — a common pattern for grouped column headers in formal reports, completely unavailable in GFM.

@(asciidoc begin)
[cols="1,1,1,1", options="header"]
|===
2+| Name and Role 2+| Contact

| First Name | Last Name | Email | Phone

| Jane | Doe | jane@example.com | 555-1234
| John | Smith | john@example.com | 555-5678
| Alice | Johnson | alice@example.com | 555-9012
|===
@( end )

## 5. Dark Theme (Pico `data-theme`)

`@{}` passes `data-*` attributes through to the wrapper `<div>`. Pico v2 scopes its dark-mode
CSS variables to any element carrying `data-theme="dark"`, so a single wrapper attribute flips
the table to dark styling without any custom CSS.

@{ data-theme="dark" }

| Quarter | Revenue | Expenses | Net |
|---------|---------|---------|-----|
| Q1 | $420,000 | $310,000 | $110,000 |
| Q2 | $385,000 | $298,000 | $87,000 |
| Q3 | $510,000 | $340,000 | $170,000 |
| Q4 | $475,000 | $320,000 | $155,000 |

@{}

## 6. Striped Rows

Pico's built-in striped-table support uses `role="grid"` on the `<table>` element. Since
`@{}` wraps a `<div>`, not the `<table>`, that attribute is out of reach. A single CSS
`nth-child` rule on a wrapper class is the portable workaround.

@{ .striped }

| City | Country | Population | Area (km²) |
|------|---------|-----------|-----------|
| Tokyo | Japan | 13,960,000 | 2,194 |
| Delhi | India | 32,940,000 | 1,484 |
| Shanghai | China | 24,870,000 | 6,341 |
| São Paulo | Brazil | 22,430,000 | 1,521 |
| Mexico City | Mexico | 21,580,000 | 1,495 |

@{}

## 7. Column and Row Targeting

CSS structural pseudo-selectors — `td:first-child`, `td:last-child`,
`tbody tr:last-child td` — target columns and the footer row without any class attributes on
individual cells. The wrapper div is the only anchor needed.

@{ .col-demo }

| Item | Jan | Feb | Mar | Total |
|------|-----|-----|-----|-------|
| Widgets | 120 | 95 | 140 | 355 |
| Gadgets | 88 | 102 | 77 | 267 |
| Doohickeys | 45 | 60 | 55 | 160 |
| **Total** | **253** | **257** | **272** | **782** |

@{}

## Styling Summary

The layout block's `---` ... `---` style section is where all table CSS lives. The pattern:

- **Global rules** — `table`, `th`, `td`, `thead th` selectors apply to every table automatically.
- **Per-table class** — wrap a table in `@{ .my-class }` to get `<div class="my-class"><table>...</table></div>`, then target it with `.my-class table { ... }`.
- **Print** — `page-break-inside: avoid` on `table` keeps tables from splitting across printed pages.

Both GFM tables and `@(asciidoc begin)` tables produce the same bare semantic HTML (`<table>`, `<thead>`, `<tbody>`, `<tr>`, `<th>`, `<td>`), so a single set of CSS rules styles both uniformly.

Attributes that must live on the `<table>` element itself — Pico's `role="grid"` for striped
rows, Bootstrap's `class="table"` — are not reachable through `@{}`. A future `@table`
directive is planned to handle this case. See `todo.txt`.

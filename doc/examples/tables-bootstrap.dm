!! documark document
!! data
---
title: "Documark Tables with Bootstrap"
language: 'en'
---
!! end
!! layout
---

  stylesheets:
  - "https://cdn.jsdelivr.net/npm/bootstrap@5/dist/css/bootstrap.min.css"

  container_class: container

---

/* Mimic Bootstrap's .table using a wrapper div class.
   Reproduces the essential visual rules without touching the <table> element. */
.bs-table table { width: 100%; border-collapse: collapse; }
.bs-table th, .bs-table td { padding: 0.5rem; border-top: 1px solid #dee2e6; }
.bs-table thead th { border-bottom: 2px solid #dee2e6; background: #f8f9fa; }
.bs-table-striped tbody tr:nth-child(odd) { background: rgba(0,0,0,.05); }

!! end

# Documark Tables with Bootstrap

Bootstrap styles tables through classes applied directly to the `<table>`, `<thead>`, and `<td>`
elements — for example `class="table table-striped table-dark"`. Documark generates bare semantic
HTML, and `@{}` wraps a `<div>` around the table rather than adding attributes to the `<table>`
element itself. This creates friction: Bootstrap's class-based API is out of reach for
standard Markdown tables.

Two practical approaches are available today.

## 1. CSS Mimicry via Wrapper Div

Define CSS rules under a wrapper class that reproduce what Bootstrap's `.table` does. The author
writes normal Markdown; the layout handles the visual style. This covers the common case — borders,
header background, padding, striped rows.

@{ .bs-table }

| Language | Paradigm | Typing | Year |
|----------|---------|--------|------|
| Ruby | OO / functional | Dynamic | 1995 |
| Go | Procedural | Static | 2009 |
| Rust | Systems | Static | 2010 |
| Python | Multi-paradigm | Dynamic | 1991 |

@{}

Add `.bs-table-striped` for alternating rows:

@{ .bs-table .bs-table-striped }

| Month | Sales | Returns | Net |
|-------|-------|---------|-----|
| Jan | 1,240 | 42 | 1,198 |
| Feb | 980 | 31 | 949 |
| Mar | 1,560 | 58 | 1,502 |
| Apr | 1,120 | 39 | 1,081 |

@{}

**What this cannot do:** Bootstrap features that depend on classes on `<table>`, `<tr>`, or `<td>`
directly — `table-dark` for dark headers, `table-hover` (requires JS), `text-end` on individual
cells — are not reachable this way. A future `@table` directive will address this. See `todo.txt`.

## 2. Raw HTML Include

For tables that genuinely need Bootstrap's classes on `<table>`, `<thead>`, or `<td>` — such as
`table-striped`, `table-dark`, per-cell `text-end` alignment, or colored `badge` spans — write
the table as an HTML file and include it:

@( include 'my-table.html' )

The included HTML has full Bootstrap class access: `class="table table-striped table-bordered"`,
`class="table-dark"` on `<thead>`, `class="text-end"` on individual cells, and Bootstrap utility
classes (`badge`, `bg-success`, etc.) anywhere inside the table.

Trade-off: the author writes and maintains raw HTML rather than Markdown. Appropriate when the
visual requirements outweigh the authoring overhead, or when an existing HTML table asset is
being embedded.

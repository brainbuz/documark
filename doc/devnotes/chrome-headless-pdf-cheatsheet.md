# Chrome headless — HTML to PDF cheatsheet

---

## Command-line flags

```sh
# Minimal
chrome --headless --print-to-pdf --no-pdf-header-footer [URL]

# Custom output path + timeout
chrome --headless --print-to-pdf=/out/doc.pdf \
  --no-pdf-header-footer --timeout=10000 [URL]

# Docker / CI
chrome --headless --print-to-pdf=/out/doc.pdf \
  --no-pdf-header-footer \
  --disable-gpu --no-sandbox --disable-dev-shm-usage \
  --timeout=15000 [URL]

# JS-heavy page — fast-forward timers instead of waiting
chrome --headless --print-to-pdf=/out/doc.pdf \
  --no-pdf-header-footer \
  --virtual-time-budget=5000 [URL]
```

| Flag | Description |
|------|-------------|
| `--headless` | Run without a visible window |
| `--print-to-pdf` | Save as `output.pdf` in the working directory |
| `--print-to-pdf=<path>` | Save to a specific path |
| `--no-pdf-header-footer` | Remove Chrome's default date/URL/page-number decorations |
| `--timeout=<ms>` | Max wait time before capture, even if the page is still loading |
| `--virtual-time-budget=<ms>` | Fast-forward JS timers (setTimeout/setInterval) without real delay — use for JS-rendered content |
| `--disable-gpu` | Disable GPU acceleration — recommended in VMs and Docker |
| `--no-sandbox` | Required when running as root in Docker — only use inside isolated containers |
| `--disable-dev-shm-usage` | Write to `/tmp` instead of `/dev/shm` — prevents crashes in Docker where `/dev/shm` is undersized |
| `--run-all-compositor-stages-before-draw` | Ensures compositor finishes before capture — helps with missing content from complex CSS |
| `--window-size=W,H` | Sets the viewport for layout; does **not** control PDF page dimensions (use CSS `@page` for that) |

> **`--virtual-time-budget` vs `--timeout`:** use `--virtual-time-budget` when the page renders via JS — it executes timers instantly. Use `--timeout` as a safety net for slow network loads.

---

## Page size — use CSS, not flags

Page dimensions, orientation, and margins are best controlled via CSS `@page`. Chrome headless respects it fully.

```css
/* Typical setup — put this in your HTML's <style> or linked stylesheet */

@page {
  size: A4 portrait;   /* or: letter, A3, landscape, 210mm 297mm … */
  margin: 20mm;        /* shorthand — all sides */
}

/* Preserve background colors and images */
@media print {
  * {
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }
}

/* Page breaks */
.page-break  { break-after: page; }
.no-break    { break-inside: avoid; }

/* Hide on-screen UI when printing */
@media print { .no-print { display: none; } }
```

### `@page size` — all named values

| Keyword | Dimensions | Notes |
|---------|-----------|-------|
| `A3` | 297 × 420 mm | ISO |
| `A4` | 210 × 297 mm | ISO — most common internationally |
| `A5` | 148 × 210 mm | ISO — half of A4 |
| `B4` | 250 × 353 mm | ISO B series |
| `B5` | 176 × 250 mm | ISO B series |
| `JIS-B4` | 257 × 364 mm | Japanese Industrial Standard |
| `JIS-B5` | 182 × 257 mm | Japanese Industrial Standard |
| `letter` | 8.5 × 11 in | US standard |
| `legal` | 8.5 × 14 in | US legal |
| `ledger` | 11 × 17 in | US tabloid / ledger |
| `auto` | — | Browser decides; matches target media |

Orientation keywords (`portrait`, `landscape`) can be appended to any named size, or used alone:

```css
size: A4 landscape;
size: letter portrait;
size: landscape;          /* orientation only — size stays auto */
size: 210mm 297mm;        /* explicit width then height */
size: 6in;                /* square */
```

### Named pages (different sizes within one document)

```css
@page wide {
  size: A4 landscape;
}

.data-table {
  page: wide;         /* this element prints on a landscape page */
}
```

### Page orientation (post-layout rotation)

Useful for rotating specific pages in the output PDF without reflowing content:

```css
@page rotated {
  size: landscape;
  page-orientation: rotate-left;   /* or: rotate-right */
}
```

---

## Margin boxes

Add generated content (page numbers, headers, etc.) into the 16 margin regions around the page area entirely via CSS.

```css
/* Page numbers */
@page :right { @bottom-right { content: counter(page); } }
@page :left  { @bottom-left  { content: counter(page); } }

/* Total page count */
@page { @bottom-center { content: "Page " counter(page) " of " counter(pages); } }

/* Dynamic header from HTML content */
h1 { string-set: doctitle content(); }

@page :right {
  @top-right {
    content: string(doctitle);
    font-size: 8pt;
    color: #666;
  }
}
```

### All 16 margin box positions

```
@top-left-corner    @top-left    @top-center    @top-right    @top-right-corner
@left-top                                                      @right-top
@left-middle                                                   @right-middle
@left-bottom                                                   @right-bottom
@bottom-left-corner @bottom-left @bottom-center @bottom-right @bottom-right-corner
```

> **Headless caveat:** external resources (images, fonts) referenced via `url()` inside margin box rules are silently ignored in headless mode. Use base64-encoded or inline SVG assets instead.

> **Zero-margin caveat:** if the first page has no margin space, Chrome suppresses browser-generated margin content on all subsequent pages too — even if they do have margins. Set a consistent margin on `@page` to avoid this.

---

## Reference links

### Chrome / Chromium

- [Chrome headless mode](https://developer.chrome.com/docs/chromium/headless) — official guide, `--print-to-pdf` flags, debugging
- [Add content to print margins with CSS](https://developer.chrome.com/blog/print-margins) — margin boxes, `@page`, generated content in margins

### MDN

- [`@page` at-rule](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@page) — full reference with examples
- [`size` descriptor](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@page/size) — all named sizes and syntax forms
- [`page` property](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/page) — named pages, applying `@page` rules to elements

### W3C specifications

- [CSS Paged Media Module Level 3](https://www.w3.org/TR/css-page-3/) — `@page`, `size`, `page-orientation`, margin boxes
- [CSS Generated Content for Paged Media](https://www.w3.org/TR/css-gcpm-3/) — `string-set`, running headers/footers, page counters

### Friendlier reading

- [Designing for Print with CSS — Smashing Magazine](https://www.smashingmagazine.com/2015/01/designing-for-print-with-css/) — accessible walkthrough of the full paged media model
- [Can I Use — @page size](https://caniuse.com/mdn-css_at-rules_page_size) — browser support table


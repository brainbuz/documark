!! documark document
!! data
---
title: "Index Sample"
language: 'en'
---
!! end
!! layout
---

  stylesheets: []

  container_class: ""

  toc:
    depth: 2
    title: "Contents"

  index:
    title: "Index"
    classes:
      dl: "index-list"

---

body {
  font-family: "Liberation Serif", "Times New Roman", serif;
  max-width: 40em;
  margin: 2em auto;
  padding: 0 1em;
  line-height: 1.5;
}

nav#toc, nav#index {
  margin: 2em 0;
  padding: 1em;
  border: 1px solid #ccc;
}

nav#toc h2, nav#index h2 {
  margin-top: 0;
}

nav#index dl.index-list {
  columns: 2;
  column-gap: 2rem;
}

nav#index dt {
  font-weight: 600;
  break-after: avoid;
}

nav#index dd {
  margin-left: 1rem;
  break-before: avoid;
}

nav#index a {
  text-decoration: none;
  color: #06c;
}

!! end

# Index Sample Document

This is a small Documark document that exercises the `@(toc)` and `@(index)` directives end to end. The body is mostly filler so the directives have something to work against.

@(toc)

## 1. Background

The American Revolution began with the @(# Battle of Lexington and Concord) Battles of Lexington and Concord on April 19, 1775. The colonial militia at @# Lexington fought a brief skirmish with British regulars before the larger engagement at @# Concord later that morning.

@# Paul-Revere's midnight ride preceded the battles by several hours, warning the militia that the British were approaching.

## 2. Tools and Formats

This document is written in @# Documark, a text-based document format that compiles to @# HTML and @# PDF. The Markdown engine is @# Kramdown, and the PDF backend is @(# WeasyPrint) WeasyPrint when paged-media features are required.

Other formats considered during the design phase included @# AsciiDoc and @# reStructuredText. @# AsciiDoc in particular influenced the index syntax, though Documark's spelling differs.

## 3. Implementation Notes

The @(# in-document tag system) tag system uses sigils `@{}`, `@[]`, `@<>`, and `@()` for different construct families. Index entries use `@(# term)` for the full form and `@# word` as a shorthand.

@# Kramdown handles the Markdown side of things. @# WeasyPrint handles paged media for PDF. @# Documark glues these together with its own preprocessor and renderer.

@(index)

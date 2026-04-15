# Documark Project Philosophy

Documark is motivated by a simple dissatisfaction with current document formats.

Too many important documents are trapped in formats that are hard to inspect, hard to diff, hard to generate, and too dependent on one application keeping its own private model of layout and styling. Plain Markdown solved part of that problem, but not enough of it.

This project is an attempt to push text-based documents further without giving up the qualities that make plain text valuable.

## 1. Documents Should Be Human-Readable

A document file should still look like a document when opened in a text editor.

It should be possible to:

- understand the structure without specialized tools
- make small edits by hand
- review changes in version control
- search and transform the content with ordinary text tooling

The format should not require a hidden binary state to remain usable.

## 2. Print Is A First-Class Use Case

Web-native formats often treat print as an afterthought.

That is not good enough for serious documents. Reports, letters, manuscripts, handouts, and many business documents still need reliable print output. A format that works only on screen is incomplete.

Documark therefore treats HTML and PDF as core targets during the prototype phase.

## 3. Prototype First, Lock In Later

The project is not pretending every early decision is permanent.

That applies especially to areas like:

- Markdown dialect choice
- metadata requirements
- extension syntax
- rendering backends

The right move at this stage is not to freeze every behavior. It is to identify which decisions are central and which are still provisional.

## 4. Plain Text Should Scale Up

There is a persistent assumption that plain text formats are only suitable for lightweight notes, README files, or programmer documentation.

Documark rejects that assumption.

A text-based format should be able to support documents that are:

- structured
- styled
- printable
- reusable
- suitable for long-form and formal work

If plain text breaks down the moment a document becomes serious, then the format has failed an important test.

## 5. More Than A Converter

The goal is not just to build another Markdown-to-HTML script.

The larger goal is to explore what an open word processing standard could look like if it started from:

- readable source
- explicit metadata
- explicit layout
- predictable rendering
- documents that survive beyond any one editor or vendor

## 6. Design Decisions

CSS is a well known and widely adapted styling mechanism that has come a long way and is capable of describing very sophisticated and specific document layout. Browsers already implement the complex process of rendering. Chromium's headless cli browsing ability provides to leverage browser rendering plus all of the print styling capability that CSS has to generate documents.

Kramdown is widely considered to be one of the best Markdown libraries -- Kramdown supports embedding style data in Markdown and popular Markdown extensions like tables. Ruby also has some excellent PDF handling libraries like hexapdf.

## 7. Motivation And Inspiration

Traditional word processing formats are usually not optimized for version control workflows. In my own long-document work, I have repeatedly run into edge cases and interoperability problems when using advanced features in mainstream editors. I've switched to Markdown and found it too limiting — even with Pandoc extensions there are limits and bugs. I've written two RPGS in AsciiDoc, and then written programs to reshape and style ascii-doctor's output.

A big part of my inspiration is AsciiDoc. It is similar to Markdown, but not the same, and it includes features that many Markdown variants do not standardize, including index terms. The main tool for working with it is Asciidoctor, also written in Ruby. Asciidoctor’s PDF theming gave me good control over print output, but its HTML styling model felt less satisfactory for deep customization, and I ended up writing tooling to restyle documents.  Doing the styling in CSS makes it easy for anyone with a foundation in development to create a layout where they can control fonts, colors, backgrounds, margins, etc.

John Karr, Inventor of Documark, 2026.

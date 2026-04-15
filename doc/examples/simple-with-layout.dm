!! documark document
!! data
title: "A Simple DocuMark Document"
!! end
!! layout
---

  stylesheets:
  - "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"

  container_class: container

---

@media screen {
/* The default */
}

@media print {

  :root {
    --pico-font-size: 11pt;
    --pico-line-height: 1.3;
  }

  @page {
    size: letter portrait;
    margin: 1in;
  }

  html, body {
    margin: 0;
    padding: 0;
  }
}
!! end

# DocuMark Makes Word Processors Obsolete!

A Document format that is human readable and human editable, with the style and formatting power of the best modern word processors and the simplicity of Markdown.
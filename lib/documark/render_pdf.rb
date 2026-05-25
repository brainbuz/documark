# frozen_string_literal: true

require 'tempfile'
require 'open3'
require 'hexapdf'
require_relative 'runtime'

module Documark
  module RenderPdf
    module_function
    extend Documark::Runtime

    # Documark started by rendering through Chrome Browsers
    # This will be kept as a comment until there is no consideration of reverting.
    # def render_pdf_with_browser(page, output_path, browser_path)
    #   ordie do
    #     raise StandardError, "Browser not found or not executable: #{browser_path}" unless File.executable?(browser_path)

    #     Tempfile.create(['documark-', '.html']) do |tmp|
    #       tmp.write(page)
    #       tmp.flush

    #       args = [
    #         browser_path,
    #         '--headless',
    #         '--disable-gpu', # Improve headless stability in CI/VMs by avoiding flaky GPU paths.
    #         '--no-pdf-header-footer',
    #         '--virtual-time-budget=3000', # Give remote assets up to 3s to load before PDF snapshot.
    #         "--print-to-pdf=#{output_path}",
    #         "file://#{tmp.path}"
    #       ]

    #       _stdout, stderr, status = Open3.capture3(*args)
    #       unless status.success?
    #         raise StandardError, "PDF render failed (exit #{status.exitstatus})\n" \
    #                              "Command: #{args.join(' ')}\n" \
    #                              "Stderr: #{stderr.strip}"
    #       end
    #     end
    #   end
    # end

    # Default WeasyPrint CSS for TOC page numbers. Injected unless the layout
    # sets toc.style: css (meaning the layout stylesheet handles it itself).
    DEFAULT_TOC_PRINT_CSS = <<~CSS.freeze
      ul#markdown-toc a::after {
        content: leader(dotted) " " target-counter(attr(href url), page);
      }
    CSS

    # Default WeasyPrint CSS for index page numbers. Injected unless the layout
    # sets index.style: css.
    DEFAULT_INDEX_PRINT_CSS = <<~CSS.freeze
      nav#index dd a::after {
        content: target-counter(attr(href url), page);
      }
    CSS

    # Build a <style> block containing any default print CSS not already
    # handled by the layout. A layout opts out of injection for a feature
    # by setting that feature's style key to 'css'.
    def _pdf_feature_styles(layout)
      toc_opts   = layout.is_a?(Hash) ? (layout['toc']   || {}) : {}
      index_opts = layout.is_a?(Hash) ? (layout['index'] || {}) : {}

      css = +""
      css << DEFAULT_TOC_PRINT_CSS   unless toc_opts['style']   == 'css'
      css << DEFAULT_INDEX_PRINT_CSS unless index_opts['style']  == 'css'

      css.empty? ? "" : "\n<style>@media print {\n#{css}}</style>"
    end

    # Build an {anchor_id => page_number} map by walking the rendered PDF's
    # named destinations. Page numbers are 1-based.
    def _read_anchor_pages(pdf_path)
      result = {}
      doc    = HexaPDF::Document.open(pdf_path)
      pages  = doc.pages.to_a
      doc.destinations.each do |name, dest|
        page_index = pages.index(dest.page)
        result[name.to_s] = page_index + 1 if page_index
      end
      result
    rescue StandardError => e
      warn "documark: could not read PDF for index dedupe: #{e.message}"
      {}
    end

    # Drop index links whose target page matches the previous kept link's
    # target page within the same term. Returns the rewritten HTML page
    # string, or the input unchanged if no anchors could be read or no
    # <nav id="index"> is present.
    def dedupe_index_pages(page, pdf_path)
      return page unless page.include?('<nav id="index"')

      anchor_pages = _read_anchor_pages(pdf_path)
      return page if anchor_pages.empty?

      page.gsub(/<dd\b[^>]*>(.*?)<\/dd>/m) do |dd|
        body  = Regexp.last_match(1)
        last  = nil
        kept  = body.scan(/<a\s+href="#(ix-[^"]+)"[^>]*>\s*<\/a>/).filter_map do |(id)|
          pg = anchor_pages[id]
          next nil if pg.nil? || pg == last

          last = pg
          %(<a href="##{id}"></a>)
        end
        kept.empty? ? dd : dd.sub(body, kept.join(", "))
      end
    end

    # Run WeasyPrint against the composed HTML, writing the PDF to output_path.
    # Appends any default print CSS not already handled by the layout.
    def render_pdf_with_weasy(page, output_path, layout = nil)
      ordie do
        Tempfile.create(['documark-', '.html']) do |tmp|
          tmp.write(page + _pdf_feature_styles(layout))
          tmp.flush

          args = ['weasyprint', tmp.path, output_path]

          _stdout, stderr, status = Open3.capture3(*args)
          unless status.success?
            raise StandardError, "PDF render failed (exit #{status.exitstatus})\n" \
                                 "Command: #{args.join(' ')}\n" \
                                 "Stderr: #{stderr.strip}"
          end
        end
      end
    end

    # Public entry point. Render a PDF from the composed HTML page. When the
    # document emitted an @(index) and the layout opts into
    # index.limit_entry_per_page, runs a second pass that drops same-page
    # repeats and re-renders.
    def render_pdf(page, output_path, layout = nil)
      render_pdf_with_weasy(page, output_path, layout)

      index_opts = layout.is_a?(Hash) ? (layout['index'] || {}) : {}
      return unless layout.is_a?(Hash) && layout['index_emitted']
      return unless index_opts['limit_entry_per_page']

      deduped = dedupe_index_pages(page, output_path)
      return if deduped.nil? || deduped == page

      render_pdf_with_weasy(deduped, output_path, layout)
    end
  end
end

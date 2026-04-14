# frozen_string_literal: true

require 'tempfile'
require 'open3'
require_relative 'runtime'

module Documark
  module RenderPdf
    module_function
    extend Documark::Runtime

    def render_pdf_with_browser(page, output_path, browser_path)
      ordie do
        raise StandardError, "Browser not found or not executable: #{browser_path}" unless File.executable?(browser_path)

        Tempfile.create(['documark-', '.html']) do |tmp|
          tmp.write(page)
          tmp.flush

          args = [
            browser_path,
            '--headless',
            '--disable-gpu', # Improve headless stability in CI/VMs by avoiding flaky GPU paths.
            '--no-pdf-header-footer',
            '--virtual-time-budget=3000', # Give remote assets up to 3s to load before PDF snapshot.
            "--print-to-pdf=#{output_path}",
            "file://#{tmp.path}"
          ]

          _stdout, stderr, status = Open3.capture3(*args)
          unless status.success?
            raise StandardError, "PDF render failed (exit #{status.exitstatus})\n" \
                                 "Command: #{args.join(' ')}\n" \
                                 "Stderr: #{stderr.strip}"
          end
        end
      end
    end
  end
end

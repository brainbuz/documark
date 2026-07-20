# frozen_string_literal: true

require 'psych'
require_relative 'runtime'

module Documark
  module Parser
    module_function
    extend Documark::Runtime

    def read_header(content)
      first_line = content.lines.first&.strip
      directive = parse_header(first_line)
      return directive if directive && directive["context"] == "documark"

      raise StandardError, "File must begin with !! documark"
    end

    def parse_header(line)
      match = line.to_s.strip.match(/\A!!\s*([a-zA-Z][a-zA-Z0-9_-]*)(?:\s+(.*))?\z/)
      return nil unless match

      fields = { "context" => match[1].downcase }

      match[2].to_s.strip.split(/\s+/).each do |token|
        key, value = token.split('=', 2)
        if value
          fields[key] = value
        elsif fields["type"].nil? && !token.empty?
          fields["type"] = token
        end
      end

      fields
    end

    def read_document(input_path)
      content = ordie { File.read(input_path) }
      header = read_header(content)
      doc = split_documark_sections(content)
      data = parse_data_section(doc["data"])

      if doc["data"].nil?
        data = {}
        data["title"] = File.basename(input_path)
        warn "No data section found; defaulting title to #{data['title']}"
      end

      {
        "content" => content,
        "header" => header,
        "doc" => doc,
        "data" => data
      }
    end

    def parse_data_section(content)
      return nil if content.nil? || content.strip.empty?
      data = Psych.safe_load(content, aliases: false)
      return data unless data.is_a?(Hash)

      # lang is an alias of language
      data['language'] ||= data['lang'] if data.key?('lang')
      data
    end

    def parse_layout_section(content)
      lines = content.to_s.lines(chomp: false)
      i = 0
      i += 1 while i < lines.length && lines[i].strip.empty?

      raise StandardError, "Layout section must start with ---" unless i < lines.length && lines[i].strip == "---"

      i += 1
      front_matter_lines = []

      while i < lines.length && lines[i].strip != "---"
        front_matter_lines << lines[i]
        i += 1
      end

      raise StandardError, "Unterminated layout front matter block" if i >= lines.length

      i += 1
      front_matter = parse_data_section(front_matter_lines.join) || {}
      raise StandardError, "Layout front matter must be a mapping" unless front_matter.is_a?(Hash)

      front_matter["style"] = (lines[i..] || []).join
      front_matter
    end

    def extract_named_section(lines, index, section_name)
      directive = parse_header(lines[index])
      return [nil, index] unless directive && directive["context"] == section_name

      index += 1
      section_lines = []

      while index < lines.length
        closing = parse_header(lines[index])
        break if closing && closing["context"] == "end"

        section_lines << lines[index]
        index += 1
      end

      raise StandardError, "Unterminated #{section_name} block" if index >= lines.length
      [section_lines.join, index + 1]
    end

    def split_documark_sections(content)
      lines = content.lines(chomp: false)
      i = 0
      raise StandardError, "File must not be empty" if lines.empty?

      header = lines[i]
      directive = read_header(header)
      i += 1

      # Allow blank lines between header and potential front matter.
      i += 1 while i < lines.length && lines[i].strip.empty?

      data, i = extract_named_section(lines, i, "data")
      i += 1 while i < lines.length && lines[i].strip.empty?
      layout, i = extract_named_section(lines, i, "layout")

      # Scan for a top-level `!! assets` section; it must be the last section
      # in the file. Everything before it is body; the archive is captured
      # verbatim and nothing but blank lines may follow its `!! end`.
      rest = lines[i..] || []
      assets_idx = rest.find_index do |line|
        header_line = parse_header(line)
        header_line && header_line["context"] == "assets"
      end

      if assets_idx.nil?
        assets = nil
        body_lines = rest
      else
        body_lines = rest[0...assets_idx]
        assets, after = extract_named_section(rest, assets_idx, "assets")
        trailing = rest[after..] || []
        unless trailing.all? { |line| line.strip.empty? }
          raise StandardError, "content after !! assets section is not allowed"
        end
      end

      {
        "header" => header,
        "header_directive" => directive,
        "data" => data,
        "layout" => layout,
        "body" => body_lines.join,
        "assets" => assets
      }
    end

    # Resolve the layout for a document and return both the parsed layout and
    # any assets that travel with it.
    #
    # Return shape: { 'layout' => <parsed layout hash>, 'assets' => <base64 String or nil> }
    #
    # An embedded document layout (a `layout` section in the document itself)
    # always wins and carries no assets of its own. Otherwise the external
    # layout file is resolved from config['layout'] (an explicit --layout /
    # stationery file), then config['default_layout'], then the built-in
    # default.dml; that file is split into sections so a stationery (.dms)
    # layout file's own `!! assets` section rides along.
    def read_layout(doc, config = {})
      if doc["layout"]
        return { "layout" => parse_layout_section(doc["layout"]), "assets" => nil }
      end

      layout_path = config['layout'] || config['default_layout'] || File.expand_path('default.dml', __dir__)
      dml = ordie { File.read(layout_path) }
      tmpl = split_documark_sections(dml)

      { "layout" => parse_layout_section(tmpl['layout']), "assets" => tmpl['assets'] }
    end
  end
end

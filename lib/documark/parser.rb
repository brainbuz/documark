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

      raise StandardError.new("File must begin with !! documark")
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
      raise 'missing frontmatter section' if doc["data"].nil?

      {
        "content" => content,
        "header" => header,
        "doc" => doc,
        "data" => parse_data_section(doc["data"])
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

      raise StandardError.new("Layout section must start with ---") unless i < lines.length && lines[i].strip == "---"

      i += 1
      front_matter_lines = []

      while i < lines.length && lines[i].strip != "---"
        front_matter_lines << lines[i]
        i += 1
      end

      raise StandardError.new("Unterminated layout front matter block") if i >= lines.length

      i += 1
      front_matter = parse_data_section(front_matter_lines.join) || {}
      raise StandardError.new("Layout front matter must be a mapping") unless front_matter.is_a?(Hash)

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

      raise StandardError.new("Unterminated #{section_name} block") if index >= lines.length
      [section_lines.join, index + 1]
    end

    def split_documark_sections(content)
      lines = content.lines(chomp: false)
      i = 0
      raise StandardError.new("File must not be empty") if lines.empty?

      header = lines[i]
      directive = read_header(header)
      i += 1

      # Allow blank lines between header and potential front matter.
      i += 1 while i < lines.length && lines[i].strip.empty?

      data, i = extract_named_section(lines, i, "data")
      i += 1 while i < lines.length && lines[i].strip.empty?
      layout, i = extract_named_section(lines, i, "layout")

      body_lines = lines[i..] || []

      {
        "header" => header,
        "header_directive" => directive,
        "data" => data,
        "layout" => layout,
        "body" => body_lines.join
      }
    end

    def read_layout(doc, config = {})
      if doc["layout"]
        parse_layout_section(doc["layout"])
      else
        layout_path = config['default_layout'] || File.expand_path('default.dml', __dir__)
        dml = ordie { File.read(layout_path) }
        tmpl = split_documark_sections(dml)
        parse_layout_section(tmpl['layout'])
      end
    end
  end
end

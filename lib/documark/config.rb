# frozen_string_literal: true

require 'fileutils'
require 'psych'
require_relative 'runtime'
require 'shellwords'

module Documark

  module ConfigTemplateData
    module_function

    def config_template
      <<~CONFTEMPL
        ---
        default_layout: ~/.documark/example_layout.dml
        template_folder: ~/Templates/
        ---
      CONFTEMPL
    end
  end

  module Config
    module_function
    extend Documark::Runtime

    DEFAULT_CONFIG_LOCATIONS = ['~/.documark/documark.conf', '~/.documark.conf'].freeze

    def config_new
      selected_path = prompt_config_path
      path = File.expand_path(selected_path)
      return unless ensure_parent_directory(path)
      return unless confirm_overwrite(path)

      ordie do
        File.write(path, ConfigTemplateData.config_template)
      end

      launch_editor(path)
      path
    end

    def read_config(file = nil)
      if file.nil?
        if File.exist?(File.expand_path('~/.documark/documark.conf'))
          file = '~/.documark/documark.conf'
        elsif File.exist?(File.expand_path('~/.documark.conf'))
          file = '~/.documark.conf'
        else
          return {}
        end
      end
      path = File.expand_path(file)
      ordie do
        content = File.read(path)
        config = Psych.safe_load(content, aliases: false) || {}
        raise StandardError.new('Config file must be a mapping') unless config.is_a?(Hash)
        config = config.transform_keys(&:to_s)
        config['default_layout'] = File.expand_path(config['default_layout']) if config['default_layout']
        config
      end
    end

    def template_new(config, options)
      template_folder = config['template_folder'] || '~/Templates/'
      template_path = prompt_template_path(template_folder)

      return unless template_path

      template_name = prompt_template_name
      return unless template_name

      dest_path = File.join(File.expand_path(template_path), template_name)

      return unless ensure_parent_directory(dest_path)
      return unless confirm_overwrite(dest_path)

      source_path = File.join(File.dirname(__FILE__), 'default.dml')
      ordie do
        FileUtils.cp(source_path, dest_path)
      end

      if prompt_yes_no("Edit #{File.basename(dest_path)} now?", default: true)
        launch_editor(dest_path)
      end

      dest_path
    end

    def prompt_template_path(suggested_path)
      puts "Where should the template be saved? [#{suggested_path}]: "
      answer = $stdin.gets
      input = answer.to_s.strip

      return suggested_path if input.empty?
      input
    end

    def prompt_template_name
      print 'Template filename (e.g., my-template.dml): '
      answer = $stdin.gets
      name = answer.to_s.strip

      if name.empty?
        warn 'Template name cannot be empty.'
        return nil
      end

      name
    end

    def prompt_config_path
      puts 'Where should the config file be saved?'
      DEFAULT_CONFIG_LOCATIONS.each_with_index do |path, index|
        puts "#{index + 1}. #{path}"
      end

      print 'Choose 1 or 2, or enter a custom path [1]: '
      answer = $stdin.gets
      input = answer.to_s.strip

      return DEFAULT_CONFIG_LOCATIONS.first if input.empty?

      choice = input.to_i
      return DEFAULT_CONFIG_LOCATIONS[choice - 1] if choice.between?(1, DEFAULT_CONFIG_LOCATIONS.length)

      input
    end

    def ensure_parent_directory(path)
      directory = File.dirname(path)
      return true if Dir.exist?(directory)

      return false unless prompt_yes_no("Directory #{directory} does not exist. Create it?", default: true)

      ordie do
        FileUtils.mkdir_p(directory)
      end
      true
    end

    def confirm_overwrite(path)
      return true unless File.exist?(path)

      prompt_yes_no("#{path} already exists. Overwrite it?", default: false)
    end

    def launch_editor(path)
      editor = ENV['VISUAL'].to_s.strip
      editor = ENV['EDITOR'].to_s.strip if editor.empty?
      editor = 'editor' if editor.empty? && executable_on_path?('editor')

      if editor.empty?
        warn "Config written to #{path}. Set VISUAL or EDITOR to launch an editor automatically."
        return
      end

      argv = Shellwords.split(editor)
      argv << path

      ordie do
        success = system(*argv)
        raise StandardError, "Failed to launch editor: #{editor}" unless success
      end
    end

    def executable_on_path?(name)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? do |dir|
        candidate = File.join(dir, name)
        File.file?(candidate) && File.executable?(candidate)
      end
    end

    def prompt_yes_no(message, default:)
      suffix = default ? ' [Y/n]: ' : ' [y/N]: '

      loop do
        print "#{message}#{suffix}"
        answer = $stdin.gets
        input = answer.to_s.strip.downcase

        return default if input.empty?
        return true if %w[y yes].include?(input)
        return false if %w[n no].include?(input)

        puts 'Please answer y or n.'
      end
    end

  end
end

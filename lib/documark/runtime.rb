# frozen_string_literal: true

module Documark
  module Runtime
    module_function

  def debug=(value)
    @debug = value
  end

  def debug?
    !!@debug
  end

    def ordie
      yield
    rescue StandardError => e
      raise if debug?
      warn e.message
      exit 1
    end
  end
end

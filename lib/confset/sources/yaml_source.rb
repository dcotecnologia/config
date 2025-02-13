# frozen_string_literal: true

require "yaml"
require "erb"

module Confset
  module Sources
    class YAMLSource
      attr_accessor :path
      attr_reader :evaluate_erb

      def initialize(path, evaluate_erb: Confset.evaluate_erb_in_yaml)
        @path = path.to_s
        @evaluate_erb = !!evaluate_erb
      end

      # returns a config hash from the YML file
      def load
        if @path && File.exist?(@path)
          file_contents = IO.read(@path)
          file_contents = ERB.new(file_contents).result if evaluate_erb
          result = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(file_contents) : YAML.load(file_contents)
        end

        result || {}

      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{@path}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
      end
    end
  end
end

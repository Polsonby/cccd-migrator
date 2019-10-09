# frozen_string_literal: true

require 'optparse'
require 'ostruct'

module Migrator
  class Options
    ENVIRONMENTS = %w[dev staging api-sandbox production].freeze
    COMPONENTS = %w[s3 rds].freeze

    class OptionsStruct < OpenStruct
      def to_s
        to_h.map { |k, v| "\t - #{k}: #{v} " }.join("\n").prepend("\n")
      end
    end

    def self.parse(args)
      options = OptionsStruct.new

      migration_opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: bin/migrate [options]"
        opts.separator ''
        opts.separator 'Specific options:'

        opts.on_head("-c", "--component COMPONENT", COMPONENTS, "AWS service to migrate #{COMPONENTS}") do |c|
          options.component = c
        end

        opts.on("-y", "--yes", 'Optional: assume yes for prompts, defaults to false') do |y|
          options.yes = y
        end

        opts.on("-s", "--summary", "Optional: output summary report only") do |s|
          options.summary = s
        end

        opts.on_tail('-h', '--help', 'Show this message') do
          puts opts
          exit
        end
      end

      migration_opt_parser.parse!(args)
      options
    end
  end
end

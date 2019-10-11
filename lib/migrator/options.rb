# frozen_string_literal: true

require 'optparse'
require 'ostruct'

module Migrator
  class Options
    class OptionsStruct < OpenStruct
      def to_s
        to_h.map { |k, v| "\t - #{k}: #{v} " }.join("\n").prepend("\n")
      end
    end

    def self.parse!(args)
      options = OptionsStruct.new

      migration_opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: bin/migrate [component] [options]"
        opts.separator 'components: s3, rds'
        opts.separator 'options:'

        opts.on("-y", "--yes", 'Optional: assume yes for prompts, defaults to false') do |y|
          options.yes = y
        end

        opts.on("-s", "--sync", "synchronize destination with source") do |s|
          options.sync = s
        end

        opts.on("-e", "--empty", "delete all destination bucket objects, for testing purposes") do |e|
          options.empty = e
        end

        opts.on("-r", "--report", "output summary report only") do |s|
          options.report = s
        end

        opts.on("-m", "--measure", "output time measurements for action performed") do |m|
          options.measure = m
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

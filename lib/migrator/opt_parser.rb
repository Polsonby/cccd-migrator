require 'optparse'
require 'ostruct'
require 'pry'

module Migrator
  class OptParser
    ENVIRONMENTS = %w[dev staging api-sandbox production].freeze

    def self.parse(args)
      options = OpenStruct.new

      migration_opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{__FILE__} [options]"
        opts.separator ''
        opts.separator 'Specific options:'

        opts.on("-s", "--source ENVIRONMENT", ENVIRONMENTS, "source environment #{ENVIRONMENTS}") do |s|
          options.source = s
        end

        opts.on("-t", "--target ENVIRONMENT", ENVIRONMENTS, "target environment #{ENVIRONMENTS}") do |t|
          options.target = t
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

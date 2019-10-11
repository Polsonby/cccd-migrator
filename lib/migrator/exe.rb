module Migrator
  class Exe
    include Helpers
    attr_reader :argv, :args, :options

    def initialize(argv)
      @argv = argv
      parse!
    end

    def call
      puts "Migrating #{component} using options: #{options.to_s}"
      self.class.continue? unless options.yes

      measure do
        case component
          when 's3'
            Migrator::S3.call(options)
          when 'rds'
            puts 'migrating rds...TODO'
          else
            puts "no such component - #{ component || 'nil' }"
        end
      end
    end

    def measure
      return yield unless options.measure
      rt = Benchmark.realtime { yield }
      puts "Took: " + rt.round(2).to_s.green + " secs"
    end

    private

    def options_parser
      Migrator::Options
    end

    def parse!
      @options = options_parser.parse!(argv)
      @args = argv
      validate
    end

    def validate
      raise "you must supply a single component to migrate. Please specify component one of #{components.join(', ')} ." unless args.size.eql?(1)
      raise "unrecognised component #{component}" unless components.include?(component)

      case component
      when 's3'
        S3.validate
      when 'rds'
        'validate rds'
      end
    end

    def component
      args.first
    end
  end
end

module Migrator
  class Exe
    attr_reader :argv, :args, :options

    def initialize(argv)
      @argv = argv
      parse!
      # validate
    end

    def call
      puts "Migrating #{component} using options: #{options.to_s}"
      self.class.continue? unless options.yes

      measure do
        case component
          when 's3'
            Migrator::S3.report if options.report
            Migrator::S3.sync if options.sync
            Migrator::S3.empty if options.empty
          when 'rds'
            puts 'migrating rds...TODO'
          else
            puts "no such component - #{ component || 'nil' }"
        end
      end
    end

    def measure
      if options.measure
        rt = Benchmark.realtime { yield }
        puts "Took: " + rt.round(2).to_s.green + "(secs)".yellow
      else
         yield
      end
    end

    def self.continue?(prompt = nil)
      prompt = prompt || 'Continue?'
      printf "\e[33m#{ prompt }\e[0m: [no/yes] "
      response = STDIN.gets.chomp
      exit unless response.match?(/^(y|yes)$/i)
      true
    end

    private

    def parse!
      @options = Migrator::Options.parse!(argv)
      @args = argv
      raise 'you must supply a single component to migrate. Please specify component s3/rds.' unless @args.size.eql?(1)
      raise "unrecognised component #{@args.first}" unless %w[s3 rds].include?(@args.first)
    end

    def validate
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

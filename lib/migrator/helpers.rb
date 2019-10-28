module Migrator
  module Helpers
    COMPONENTS = %w[s3 rds].freeze
    REQUIRE_SSL = '?sslmode=require'.freeze

    def self.included(base)
      base.include InstanceMethods
      base.extend ClassMethods
    end

    module InstanceMethods
      def components
        Helpers::COMPONENTS
      end
    end

    module ClassMethods
      def configuration
        Migrator.configuration
      end
      alias_method :config, :configuration

      def source_region
        config.s3.source.region
      end

      def destination_region
        config.s3.destination.region
      end

      def source_bucket_name
        config.s3.source.bucket_name
      end

      def destination_bucket_name
        config.s3.destination.bucket_name
      end

      def source_bucket
        "s3://#{source_bucket_name}"
      end

      def destination_bucket
        "s3://#{destination_bucket_name}"
      end

      def source_database_url
        config.rds.source.database_url + require_ssl
      end

      def source_database_name
        config.rds.source.database_name
      end

      def destination_database_url
        config.rds.destination.database_url + require_ssl
      end

      def destination_database_name
        config.rds.destination.database_name
      end

      def destination_database_username
        config.rds.destination.database_username
      end

      def destination_database_password
        config.rds.destination.database_password
      end

      def destination_database_host
        config.rds.destination.database_host
      end

      def require_ssl
        Helpers::REQUIRE_SSL
      end

      def components
        Helpers::COMPONENTS
      end

      def continue?(prompt = nil)
        prompt = prompt || 'Continue?'
        printf prompt.yellow + ": [no/yes] "
        response = STDIN.gets.chomp
        exit unless response.match?(/^(y|yes)$/i)
        true
      end

      def execute(cmd, output_count: false)
        Open3.popen2e(cmd.join(' ')) do |stdin, stdout_and_stderr, wait_thr|
          count = 0
          stdout_and_stderr.each_line do |line|
            count += 1
            printf line
          end
          raise ['Failure'.red, ': ', cmd.join(' ')].join unless wait_thr.value.success?
          puts "Succeeded: #{count} lines of output".green if output_count
        end
      end

      def cmd
        self::Commands
      end
    end
  end
end

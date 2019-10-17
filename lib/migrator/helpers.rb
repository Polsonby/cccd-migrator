module Migrator
  module Helpers
    COMPONENTS = %w[s3 rds].freeze

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
            printf "#{count}: #{line}"
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

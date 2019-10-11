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
        printf "\e[33m#{ prompt }\e[0m: [no/yes] "
        response = STDIN.gets.chomp
        exit unless response.match?(/^(y|yes)$/i)
        true
      end

      def execute(cmd, output_count: false)
        Open3.popen2(cmd.join(' ')) do |stdin, stdout, status_thread|
          count = 0
          stdout.each_line do |line|
            count += 1
            printf line
          end
          raise 'Failed'.red unless status_thread.value.success?
          puts "Succeeded: #{count} lines of output".green if output_count
        end
      end

      def cmd
        self::Commands
      end
    end
  end
end

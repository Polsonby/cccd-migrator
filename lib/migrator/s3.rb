# frozen_string_literal: true
require 'open3'
require 'colorize'

module Migrator
  module S3
    class << self
      def sync
        Open3.popen2(*cmd.sync) do |stdin, stdout, status_thread|
          count = 0
          stdout.each_line do |line|
            count += 1
            puts line.green
          end
          raise 'Sync failed'.red unless status_thread.value.success?
          puts "Sync succeeded: #{[count-1, 0].max} files synchronized".green
        end
      end

      def report
        puts ''
        puts 'Source bucket:'.yellow
        puts '----------------------------'.yellow
        execute(cmd.summarize(source_bucket_name))
        puts ''
        puts 'Destination bucket:'.yellow
        puts '----------------------------'.yellow
        execute(cmd.summarize(destination_bucket_name))
      end

      def empty
        raise 'No bucket configured' unless S3.destination_bucket_name
        Exe.continue?("This will delete all objects in #{S3.destination_bucket_name}. Are you sure?")
        execute(cmd.empty, output_count: true)
      end

      def source_bucket_name
        ENV.fetch('SOURCE_AWS_S3_BUCKET_NAME', nil)
      end

      def destination_bucket_name
        ENV.fetch('DESTINATION_AWS_S3_BUCKET_NAME', nil)
      end

      def source_bucket
        "s3://#{source_bucket_name}"
      end

      def destination_bucket
        "s3://#{destination_bucket_name}"
      end

      def source_region
        ENV['SOURCE_AWS_REGION']
      end

      def destination_region
        ENV['AWS_REGION']
      end

      def validate
        raise 'no destination bucket configured' unless destination_bucket_name && source_bucket_name
      end

      private

      def cmd
        Commands
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
    end
  end
end

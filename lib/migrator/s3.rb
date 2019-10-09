# frozen_string_literal: true
require 'open3'
require 'colorize'

module Migrator
  module S3
    class << self
      def sync
        Open3.popen2(*sync_cmd) do |stdin, stdout, status_thread|
          count = 0
          stdout.each_line do |line|
            count += 1
            puts line.green
          end
          raise 'Sync failed'.red unless status_thread.value.success?
          puts "Sync succeeded: #{[count-1, 0].max} files synchronized".green
        end
      end

      def summary
        puts ''
        puts 'Source bucket:'.yellow
        puts '----------------------------'.yellow
        execute(summarize(source_bucket_name))
        puts ''
        puts 'Destination bucket:'.yellow
        puts '----------------------------'.yellow
        execute(summarize(destination_bucket_name))
      end

      private

      def sync_cmd
        ['aws', 's3', 'sync', '--delete', source_bucket, destination_bucket, '--source-region', source_region, '--region', destination_region]
      end

      def execute(cmd)
        Open3.popen2(cmd.join(' ')) do |stdin, stdout, status_thread|
          puts stdout.read
        end
      end

      def summarize(bucket_name)
        ['aws', 's3', 'ls', bucket_name, '--recursive', '--human-readable', '--summarize',
        '>',
        "/tmp/#{bucket_name}_summary.txt",
        '&&', 'tail', '-n', '2', "/tmp/#{bucket_name}_summary.txt"]
      end

      def source_bucket_name
        ENV['SOURCE_AWS_S3_BUCKET_NAME']
      end

      def destination_bucket_name
        ENV['DESTINATION_AWS_S3_BUCKET_NAME']
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
    end
  end
end

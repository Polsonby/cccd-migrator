# frozen_string_literal: true
require 'open3'
require 'colorize'

module Migrator
  module S3
    include Helpers

    class << self
      def call(options)
        report if options.report
        sync if options.sync
        empty if options.empty
      end

      def sync
        Open3.popen2(*cmd.sync) do |stdin, stdout, status_thread|
          count = 0
          stdout.each_line do |line|
            count += 1
            puts line.green
          end
          raise 'Sync failed'.red unless status_thread.value.success?
          puts 'Sync succeeded: ' + [count-1, 0].max.to_s.green + ' files synchronized'
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
        continue?("This will delete all objects in #{destination_bucket_name}. Are you sure?")
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
        raise 'no source or destination buckets configured' unless destination_bucket_name && source_bucket_name
      end
    end
  end
end

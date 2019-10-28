# frozen_string_literal: true

module Migrator
  module Rds
    include Helpers

    class << self
      def call(options)
        test_connection(destination_database_url)
        test_connection(source_database_url)

        report if options.report
        sync(piped: options.pipe) if options.sync
      end

      def sync(piped: false)
        empty

        if piped
          execute(cmd.pipe('pre-data'))
          execute(cmd.pipe('data'))
          execute(cmd.pipe('post-data'))
        else
          export('pre-data')
          import('pre-data')
          export('data')
          import('data')
          export('post-data')
          import('post-data')
        end

        analyze(verbose: true)
      end

      def export(section)
        execute(cmd.export(section))
      end

      def import(section)
        execute(cmd.import(section))
      end

      def report
        puts ''
        puts 'Source & Destination table counts:'.yellow
        puts '-----------------------------------'.yellow
        cmd.table_counts_output
        puts ''
        puts 'Source & Destination sequence IDs:'.yellow
        puts '-----------------------------------'.yellow
        cmd.sequence_last_values_output
        puts ''
      end

      def terminate_connections
        execute(cmd.terminate_connections(destination_database_url, destination_database_name))
      rescue RuntimeError
        puts 'Connections terminated as requested!'.green
      end

      def dropdb
        execute(cmd.dropdb)
      rescue RuntimeError => e
        puts "DB #{destination_database_name} could not be dropped!".red
        raise e
      end

      def createdb
        execute(cmd.createdb)
      end

      def empty
        continue?("Database #{ destination_database_name || 'nil' } will be dropped! Are you sure?")
        terminate_connections
        dropdb
        createdb
      end

      def analyze(verbose: false)
        execute(cmd.analyze(verbose))
      end

      def validate
        raise 'source database connection missing' unless source_database_url
        raise 'destination database connections missing' unless destination_database_url &&
          destination_database_name &&
          destination_database_username &&
          destination_database_host
      end

      private

      def test_connection(url)
        execute(cmd.test_conn(url))
      rescue RuntimeError
        dbname = URI.parse(url)&.path&.tr('/','')
        puts "Unable to connect to DB #{dbname}!".red
        continue?('Proceed anyway?')
      end
    end
  end
end

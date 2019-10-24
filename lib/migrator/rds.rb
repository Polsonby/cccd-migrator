# frozen_string_literal: true

module Migrator
  module Rds
    include Helpers

    class << self
      def call(options)
        test_connection
        report if options.report
        sync(piped: options.pipe) if options.sync
      end

      def test_connection
        execute(cmd.test_conn)
      rescue RuntimeError
        puts "Unable to connect to DB #{destination_database_name}!".red
        continue?('Proceed anyway?')
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

      # TODO
      def report
        puts ''
        puts 'Source & Destination tuple count:'.yellow
        puts '----------------------------'.yellow
        cmd.summarize
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
    end
  end
end

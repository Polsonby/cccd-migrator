module Migrator
  module S3
    module Commands
      include Helpers

      class << self
        def sync
          ['aws', 's3', 'sync', '--delete', source_bucket, destination_bucket, '--source-region', source_region, '--region', destination_region]
        end

        def summarize(bucket_name)
          ['aws', 's3', 'ls', bucket_name, '--recursive', '--human-readable', '--summarize',
          '>', "/tmp/#{bucket_name}_summary.txt",
          '&&',
          'tail', '-n', '2', "/tmp/#{bucket_name}_summary.txt"]
        end

        def empty
          ['aws', 's3', 'rm', destination_bucket, '--recursive']
        end
      end
    end
  end

  module Rds
    module Commands
      include Helpers

      class << self
        def test_conn
          [
            'psql',
            destination_database_url,
            '-c',
            "\"select current_database();\""
          ]
        end

        #
        # PGPASSWORD=$DESTINATION_DATABASE_PASSWORD dropdb --host=$DESTINATION_DATABASE_HOST --username=$DESTINATION_DATABASE_USERNAME $DESTINATION_DATABASE_NAME
        #
        def dropdb
          [
            "PGPASSWORD=#{destination_database_password}",
            'dropdb',
            '--echo',
            "--host=#{destination_database_host}",
            "--username=#{destination_database_username}",
            destination_database_name
          ]
        end

        #
        # PGPASSWORD=$DESTINATION_DATABASE_PASSWORD createdb --encoding=utf-8 --owner=$DESTINATION_DATABASE_USERNAME --host=$DESTINATION_DATABASE_HOST --username=$DESTINATION_DATABASE_USERNAME $DESTINATION_DATABASE_NAME
        #
        def createdb
          [
            "PGPASSWORD=#{destination_database_password}",
            'createdb',
            '--echo',
            "--encoding=utf-8",
            "--owner=#{destination_database_username}",
            "--host=#{destination_database_host}",
            "--username=#{destination_database_username}",
            destination_database_name
          ]
        end

        #
        # PGPASSWORD=$DESTINATION_DATABASE_PASSWORD psql --list --host=$DESTINATION_DATABASE_HOST --username=$DESTINATION_DATABASE_USERNAME
        #
        def list_dbs(url)
          [
            'psql',
            url,
            '--list'
          ]
        end

        #
        # psql $DESTINATION_DATABASE_URL --command="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DESTINATION_DATABASE_NAME}';"
        #
        def terminate_connections(url, dbname)
          [
            'psql',
            url,
            '-c',
            "\"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{dbname}';\""
          ]
        end

        # Prevents new connections on dbname.
        # CANNOT work out away to use pg_dump options to dump a
        # database that cannot be connected to though, without superuser.
        # def allow_connections(url, dbname, allow = true)
        #   url.sub!(dbname, 'postgres')
        #   ['psql', url, '-c', "ALTER DATABASE #{dbname} WITH ALLOW_CONNECTIONS #{allow};"]
        # end

        def sections
          ['pre-data','data','post-data']
        end

        def export(section)
          puts "EXPORTING #{section}".yellow

          # TODO the sed command is only required from pre-data
          #
          raise "invalid export section specified. must be one of #{sections.join(', ')}" unless sections.include? section
          [
            'pg_dump',
            source_database_url,
            '--no-owner',
            "--format=plain",
            "--section=#{section}",
            '|',
            'sed','-E', "'s/(COMMENT ON EXTENSION.*)/-- \1/'",
            '>', "/tmp/#{section}.sql"
          ]
        end

        def import(section)
          puts "IMPORTING #{section}".yellow
          raise "invalid import section specified. must be one of #{sections.join(', ')}" unless sections.include? section
          [
            'psql',
            destination_database_url,
            '--set', 'ON_ERROR_STOP=on' ,
            '-f', "/tmp/#{section}.sql"
          ]
        end

        def pipe(section)
          raise "invalid import section specified. must be one of #{sections.join(', ')}" unless sections.include? section
          [
            'pg_dump',
            source_database_url,
            '--no-owner',
            "--format=plain",
            "--section=#{section}",
            '|',
            'sed','-E', "'s/(COMMENT ON EXTENSION.*)/-- \1/'",
            '|',
            'psql',
            destination_database_url,
            '--set', 'ON_ERROR_STOP=on'
          ]
        end

        def analyze(verbose = false)
          ['psql', destination_database_url, '-c', "ANALYZE#{' VERBOSE' if verbose};"]
        end

        def summarize
          destination_rs = pg_exec(destination_database_url, live_tuple_count)
          dst = destination_rs.each_with_object({}) {|rec, h| h[rec['relname']] = rec['n_live_tup'] }

          source_rs = pg_exec(source_database_url, live_tuple_count)
          src = source_rs.each_with_object({}) {|rec, h| h[rec['relname']] = rec['n_live_tup'] }

          padding = src.keys.map(&:length).max + 2

          puts "#{'relname'.ljust(padding, ' ')}source count  destination count"
          src.each do |relname, count|
            color = count.eql?(dst[relname]) ? :green : :red
            puts "#{relname.ljust(padding, ' ')}#{count.ljust(14, ' ')}#{dst[relname]}".send(color)
          end

          # TODO
          # current sequence values for sequences
        end

        def pg_exec(url, sql)
          uri = URI.parse(url)
          conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
          rs = conn.exec(sql)
        end

        def live_tuple_count
          <<~SQL
            SELECT schemaname, relname, n_live_tup
            FROM pg_stat_user_tables
            ORDER BY relname, n_live_tup DESC;
          SQL
        end
      end
    end
  end
end

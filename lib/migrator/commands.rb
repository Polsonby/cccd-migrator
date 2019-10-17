module Migrator
  module S3
    module Commands
      class << self
        def sync
          ['aws', 's3', 'sync', '--delete', S3.source_bucket, S3.destination_bucket, '--source-region', S3.source_region, '--region', S3.destination_region]
        end

        def summarize(bucket_name)
          ['aws', 's3', 'ls', bucket_name, '--recursive', '--human-readable', '--summarize',
          '>', "/tmp/#{bucket_name}_summary.txt",
          '&&',
          'tail', '-n', '2', "/tmp/#{bucket_name}_summary.txt"]
        end

        def empty
          ['aws', 's3', 'rm', S3.destination_bucket, '--recursive']
        end
      end
    end
  end

  module Rds
    module Commands
      class << self
        def test_conn
          [
            'psql',
            Rds.destination_database_url,
            '-c', "\"select 'connected to DB ' || current_database() || ' as user ' || current_user as conn_details;\""
          ]
        end

        #
        # PGPASSWORD=$DESTINATION_DATABASE_PASSWORD dropdb --host=$DESTINATION_DATABASE_HOST --username=$DESTINATION_DATABASE_USERNAME $DESTINATION_DATABASE_NAME
        #
        def dropdb
          [
            "PGPASSWORD=#{Rds.destination_database_password}",
            'dropdb',
            '--echo',
            "--host=#{Rds.destination_database_host}",
            "--username=#{Rds.destination_database_username}",
            Rds.destination_database_name
          ]
        end

        #
        # PGPASSWORD=$DESTINATION_DATABASE_PASSWORD createdb --encoding=utf-8 --owner=$DESTINATION_DATABASE_USERNAME --host=$DESTINATION_DATABASE_HOST --username=$DESTINATION_DATABASE_USERNAME $DESTINATION_DATABASE_NAME
        #
        def createdb
          [
            "PGPASSWORD=#{Rds.destination_database_password}",
            'createdb',
            '--echo',
            "--encoding=utf-8",
            "--owner=#{Rds.destination_database_username}",
            "--host=#{Rds.destination_database_host}",
            "--username=#{Rds.destination_database_username}",
            Rds.destination_database_name
          ]
        end

        #
        # PGPASSWORD=$DESTINATION_DATABASE_PASSWORD psql --list --host=$DESTINATION_DATABASE_HOST --username=$DESTINATION_DATABASE_USERNAME
        #
        def list_dbs
          [
            "PGPASSWORD=#{Rds.destination_database_password}",
            'psql', '--list',
            '-h', Rds.destination_database_host,
            '-U', Rds.destination_database_username
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
          puts "EXPORTING #{section}"

          # TODO the sed command is only required from pre-data
          #
          raise "invalid export section specified. must be one of #{sections.join(', ')}" unless sections.include? section
          [
            'pg_dump',
            Rds.source_database_url,
            '--no-owner',
            "--format=plain",
            "--section=#{section}",
            '|',
            'sed','-E', "'s/(COMMENT ON EXTENSION.*)/-- \1/'",
            '>', "/tmp/#{section}.sql"
          ]
        end

        def import(section)
          puts "IMPORTING #{section}"
          raise "invalid import section specified. must be one of #{sections.join(', ')}" unless sections.include? section
          [
            'psql',
            Rds.destination_database_url,
            '--set', 'ON_ERROR_STOP=on' ,
            '-f', "/tmp/#{section}.sql"
          ]
        end

        def pipe(section)
          raise "invalid import section specified. must be one of #{sections.join(', ')}" unless sections.include? section
          ['pg_dump', Rds.source_database_url, "--section=#{section}", '|', 'psql', Rds.destination_database_url, '--set', 'ON_ERROR_STOP=on']
        end

        def summarize
          # TODO
          # number of tuples per table
          # current sequence values for sequences
        end

        def analyze(verbose = false)
          ['psql', Rds.destination_database_url, '-c', "ANALYZE#{' VERBOSE' if verbose};"]
        end
      end
    end
  end
end

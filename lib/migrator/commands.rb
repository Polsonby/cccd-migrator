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
        def test_conn(url)
          [
            'psql',
            url,
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

        def table_counts_output
          dst = table_counts(destination_database_url)
          src = table_counts(source_database_url)

          pad = src.keys.map(&:length).max + 2

          puts "#{'table_name'.rpad(pad)}#{'source'.rpad(pad)}#{'destination'.rpad(pad)}"
          src.each do |table, count|
            color = count.eql?(dst[table]) ? :green : :red
            puts "#{table.rpad(pad)}#{count.rpad(pad)}#{dst[table].rpad(pad)}".send(color)
          end
        end

        def sequence_last_values_output
          dst = sequence_ids(destination_database_url)
          src = sequence_ids(source_database_url)

          pad = src.keys.map(&:length).max + 2

          puts "#{'sequence_name'.rpad(pad)}#{'source'.rpad(pad)}#{'destination'.rpad(pad)}"
          src.each do |seq, value|
            color = value.eql?(dst[seq]) ? :green : :red
            puts "#{seq.rpad(pad)}#{value.rpad(pad)}#{dst[seq].rpad(pad)}".send(color)
          end
        end

        private

        def pg_exec(url, sql)
          uri = URI.parse(url)
          conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
          conn.exec(sql)
        end

        def all_table_counts_func
          <<~TABCOUNT_FUNC
            CREATE OR REPLACE FUNCTION all_table_counts() RETURNS TABLE(table_name text, tuple_count bigint)
            AS
            $body$
            BEGIN
              FOR table_name IN (SELECT
                                    c.relname AS tablename
                                  FROM pg_class c
                                  LEFT JOIN pg_namespace n ON (n.oid = c.relnamespace)
                                  WHERE
                                    nspname NOT IN ('pg_catalog', 'information_schema')
                                    AND relkind='r')
              LOOP
                RETURN QUERY EXECUTE 'SELECT ' || quote_literal(table_name) || '::text as table_name, count(*) as tuple_count FROM ' || table_name;
              END LOOP;
              RETURN;
            END
            $body$
            LANGUAGE 'plpgsql';
          TABCOUNT_FUNC
        end

        def drop_all_table_counts_func
          'DROP FUNCTION all_table_counts();'
        end

        def all_table_counts_sql
          'SELECT * FROM all_table_counts() ORDER BY table_name;'
        end

        def table_counts(url)
          pg_exec(url, all_table_counts_func)
          rs = pg_exec(url, all_table_counts_sql)
          rs.each_with_object({}) { |rec, h| h[rec['table_name']] = rec['tuple_count'] }
        ensure
          pg_exec(url, drop_all_table_counts_func)
        end

        def all_sequence_ids_func
          <<~SEQID_FUNC
            CREATE OR REPLACE FUNCTION all_sequence_ids() RETURNS TABLE(sequence_name text, last_value bigint)
            AS
            $body$
            BEGIN
              FOR sequence_name IN (SELECT c.relname AS sequencename FROM pg_class c WHERE (c.relkind = 'S'))
              LOOP
                RETURN QUERY EXECUTE 'SELECT ' || quote_literal(sequence_name) || '::text, last_value FROM ' || sequence_name;
              END LOOP;
              RETURN;
            END
            $body$
            LANGUAGE 'plpgsql';
          SEQID_FUNC
        end

        def drop_all_sequence_ids_func
          'DROP FUNCTION all_sequence_ids();'
        end

        def all_sequence_ids_sql
          'SELECT * FROM all_sequence_ids() ORDER BY sequence_name;'
        end

        def sequence_ids(url)
          pg_exec(url, all_sequence_ids_func)
          rs = pg_exec(url, all_sequence_ids_sql)
          rs.each_with_object({}) { |rec, h| h[rec['sequence_name']] = rec['last_value'] }
        ensure
          pg_exec(url, drop_all_sequence_ids_func)
        end
      end
    end
  end
end

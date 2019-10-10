module Migrator
  module S3
    module Commands
      class << self
        def sync
          ['aws', 's3', 'sync', '--delete', S3.source_bucket, S3.destination_bucket, '--source-region', S3.source_region, '--region', S3.destination_region]
        end

        def summarize(bucket_name)
          ['aws', 's3', 'ls', bucket_name, '--recursive', '--human-readable', '--summarize',
          '>',
          "/tmp/#{bucket_name}_summary.txt",
          '&&', 'tail', '-n', '2', "/tmp/#{bucket_name}_summary.txt"]
        end

        def empty
          ['aws', 's3', 'rm', S3.destination_bucket, '--recursive']
        end
      end
    end
  end
end

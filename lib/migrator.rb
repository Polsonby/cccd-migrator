require 'colorize'
require 'benchmark'
require 'pry-byebug'
require 'pg'
require_relative 'migrator/extensions'
require_relative 'migrator/configuration'
require_relative 'migrator/helpers'
require_relative 'migrator/options'
require_relative 'migrator/commands'
require_relative 'migrator/s3'
require_relative 'migrator/rds'
require_relative 'migrator/exe'

Migrator.configure do |config|
  config.s3.source.region = ENV.fetch('SOURCE_AWS_REGION', nil)
  config.s3.source.bucket_name = ENV.fetch('SOURCE_AWS_S3_BUCKET_NAME', nil)
  config.s3.destination.region = ENV.fetch('AWS_REGION', nil)
  config.s3.destination.bucket_name = ENV.fetch('DESTINATION_AWS_S3_BUCKET_NAME', nil)

  config.rds.source.database_url = ENV.fetch('SOURCE_DATABASE_URL', nil)
  config.rds.source.database_name = ENV.fetch('SOURCE_DATABASE_NAME', nil)
  config.rds.destination.database_url = ENV.fetch('DESTINATION_DATABASE_URL', nil)
  config.rds.destination.database_username = ENV.fetch('DESTINATION_DATABASE_USERNAME', nil)
  config.rds.destination.database_password = ENV.fetch('DESTINATION_DATABASE_PASSWORD', nil)
  config.rds.destination.database_host = ENV.fetch('DESTINATION_DATABASE_HOST', nil)
  config.rds.destination.database_name = ENV.fetch('DESTINATION_DATABASE_NAME', nil)
end

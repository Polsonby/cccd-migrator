# frozen_string_literal: true

module Migrator
  module S3
    class Configuration
      attr_accessor :source, :destination

      Struct.new('S3Config', :region, :bucket_name)

      def initialize
        @source = source_defaults
        @destination = destination_defaults
      end

      private

      def source_defaults
        @source_defaults ||= Struct::S3Config.new(
          ENV.fetch('SOURCE_AWS_REGION', nil),
          ENV.fetch('SOURCE_AWS_S3_BUCKET_NAME', nil)
        )
      end

      def destination_defaults
        @destination_defaults ||= Struct::S3Config.new(
          ENV.fetch('DESTINATION_AWS_REGION', nil),
          ENV.fetch('DESTINATION_AWS_S3_BUCKET_NAME', nil)
        )
      end
    end
  end

  module Rds
    class Configuration
      attr_accessor :source, :destination

      Struct.new(
        'RdsConfig',
        :database_url,
        :database_username,
        :database_password,
        :database_host,
        :database_name
      )

      def initialize
        @source = source_defaults
        @destination = destination_defaults
      end

      private

      def source_defaults
        @source_defaults ||= Struct::RdsConfig.new(
          ENV.fetch('SOURCE_DATABASE_URL', nil),
          ENV.fetch('SOURCE_DATABASE_NAME', nil)
        )
      end

      def destination_defaults
        @destination_defaults ||= Struct::RdsConfig.new(
          ENV.fetch('DESTINATION_DATABASE_URL', nil),
          ENV.fetch('DESTINATION_DATABASE_USERNAME', nil),
          ENV.fetch('DESTINATION_DATABASE_PASSWORD', nil),
          ENV.fetch('DESTINATION_DATABASE_HOST', nil),
          ENV.fetch('DESTINATION_DATABASE_NAME', nil)
        )
      end
    end
  end

  class Configuration
    attr_accessor :s3, :rds

    def initialize
      @s3 = S3::Configuration.new
      @rds = Rds::Configuration.new
    end
  end

  class << self
    attr_writer :configuration
    def configuration
      @configuration ||= Configuration.new
    end
    alias_method :config, :configuration

    def configure
      yield(configuration) if block_given?
      configuration
    end
  end
end

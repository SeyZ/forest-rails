require 'rack/cors'
require 'jsonapi-serializers'
require 'groupdate'
require 'net/http'
require 'useragent'
require 'jwt'
require 'bcrypt'
require_relative 'bootstrapper'
require_relative 'collection'

module Rack
  class Cors
    class Resource
      def to_preflight_headers(env)
        h = to_headers(env)
        h['Access-Control-Allow-Private-Network'] = 'true' if env['HTTP_ACCESS_CONTROL_REQUEST_PRIVATE_NETWORK'] == 'true'
        if env[HTTP_ACCESS_CONTROL_REQUEST_HEADERS]
          h.merge!('Access-Control-Allow-Headers' => env[HTTP_ACCESS_CONTROL_REQUEST_HEADERS])
        end
        h
      end
    end
  end
end

module ForestLiana
  class Engine < ::Rails::Engine
    isolate_namespace ForestLiana

    def configure_forest_cors
      begin
        rack_cors_class = Rack::Cors
        rack_cors_class = 'Rack::Cors' if Rails::VERSION::MAJOR < 5
        null_regex = Regexp.new(/\Anull\z/)

        config.middleware.insert_before 0, rack_cors_class do
          allow do
            hostnames = [null_regex, 'localhost:4200', /\A.*\.forestadmin\.com\z/]
            hostnames += ENV['CORS_ORIGINS'].split(',') if ENV['CORS_ORIGINS']

            origins hostnames
            resource ForestLiana::AuthenticationController::PUBLIC_ROUTES[1], headers: :any, methods: :any, credentials: true, max_age: 86400 # NOTICE: 1 day
          end

          allow do
            hostnames = ['localhost:4200', /\A.*\.forestadmin\.com\z/]
            hostnames += ENV['CORS_ORIGINS'].split(',') if ENV['CORS_ORIGINS']

            origins hostnames
            resource '*', headers: :any, methods: :any, credentials: true, max_age: 86400 # NOTICE: 1 day
          end
        end
        nil
      rescue => exception
        FOREST_REPORTER.report exception
        exception
      end
    end

    def rake?
      File.basename($0) == 'rake'
    end

    def database_available?
      database_available = true
      begin
        ActiveRecord::Base.connection_pool.with_connection { |connection| connection.active? }
      rescue => error
        database_available = false
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "No Apimap sent to Forest servers, it seems that the database is not accessible:\n#{error}"
      end
      database_available
    end

    error = configure_forest_cors unless ENV['FOREST_CORS_DEACTIVATED']

    def eager_load_active_record_descendants app
      # HACK: Force the ActiveRecord descendants classes from ActiveStorage to load for
      #       introspection.
      if defined? ActiveStorage
        ActiveStorage::Blob
        ActiveStorage::Attachment
      end

      if Rails::VERSION::MAJOR > 5 && Rails.autoloaders.zeitwerk_enabled?
        Zeitwerk::Loader.eager_load_all
      else
        app.eager_load!
      end
    end

    config.after_initialize do |app|
      if error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Impossible to set the whitelisted Forest " \
          "domains for CORS constraint:\n#{error}"
      end
      
      # if there are running pending migrations thru `rails db:migrate`, don't load ALL the models
      if database_available? && !ActiveRecord::Base.connection.migration_context.needs_migration?
        eager_load_active_record_descendants(app)
      end

      if database_available?
        # NOTICE: Do not run the code below on rails g forest_liana:install.
        if ForestLiana.env_secret || ForestLiana.secret_key
          unless rake?
            bootstrapper = Bootstrapper.new
            if ENV['FOREST_DEACTIVATE_AUTOMATIC_APIMAP']
              FOREST_LOGGER.warn "DEPRECATION WARNING: FOREST_DEACTIVATE_AUTOMATIC_APIMAP option has been renamed. Please use FOREST_DISABLE_AUTO_SCHEMA_APPLY instead."
            end
            bootstrapper.synchronize unless ENV['FOREST_DEACTIVATE_AUTOMATIC_APIMAP'] == true || ENV['FOREST_DISABLE_AUTO_SCHEMA_APPLY'] == true || Rails.env.test?
          end
        end
      end
    end
  end
end

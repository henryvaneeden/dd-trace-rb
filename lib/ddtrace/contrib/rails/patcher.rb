module Datadog
  module Contrib
    module Rails
      # Patcher
      module Patcher
        include Base
        register_as :rails, auto_patch: true

        option :service_name
        option :controller_service
        option :cache_service
        option :database_service
        option :distributed_tracing, default: false
        option :template_base_path, default: 'views/'
        option :tracer, default: Datadog.tracer

        @patched = false

        class << self
          def patch
            return @patched if patched? || !compatible?
            require_relative 'framework'
            @patched = true
          rescue => e
            Datadog::Tracer.log.error("Unable to apply Rails integration: #{e}")
            @patched
          end

          def patched?
            @patched
          end

          def compatible?
            return if ENV['DISABLE_DATADOG_RAILS']

            defined?(::Rails::VERSION) && ::Rails::VERSION::MAJOR.to_i >= 3
          end
        end
      end
    end
  end
end

require 'ddtrace/contrib/rails/railtie' if Datadog.registry[:rails].compatible?

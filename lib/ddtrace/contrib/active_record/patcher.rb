module Datadog
  module Contrib
    module ActiveRecord
      # Patcher enables patching of 'active_record' module.
      # This is used in monkey.rb to manually apply patches
      module Patcher
        include Base
        register_as :active_record, auto_patch: false
        option :service_name

        @patched = false

        module_function

        # patched? tells whether patch has been successfully applied
        def patched?
          @patched
        end

        def patch
          if !@patched && defined?(::ActiveRecord)
            begin
              require 'ddtrace/contrib/rails/utils'
              require 'ddtrace/ext/sql'
              require 'ddtrace/ext/app_types'

              patch_active_record()

              @patched = true
            rescue StandardError => e
              Datadog::Tracer.log.error("Unable to apply Active Record integration: #{e}")
            end
          end

          @patched
        end

        def patch_active_record
          # subscribe when the active record query has been processed
          ::ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
            sql(*args)
          end
        end

        def self.adapter_name
          @adapter_name ||= Datadog::Contrib::Rails::Utils.adapter_name
        end

        def self.tracer
          @tracer ||= Datadog.configuration[:sinatra][:tracer]
        end

        def self.database_service
          return @database_service if defined?(@database_service)

          @database_service = get_option(:service_name) || adapter_name
          tracer.set_service_info(@database_service, 'sinatra', Ext::AppTypes::DB)
          @database_service
        end

        def self.sql(_name, start, finish, _id, payload)
          span_type = Datadog::Ext::SQL::TYPE

          span = tracer.trace(
            "#{adapter_name}.query",
            resource: payload.fetch(:sql),
            service: database_service,
            span_type: span_type
          )

          # the span should have the query ONLY in the Resource attribute,
          # so that the ``sql.query`` tag will be set in the agent with an
          # obfuscated version
          span.span_type = Datadog::Ext::SQL::TYPE
          span.set_tag('active_record.db.vendor', adapter_name)
          span.start_time = start
          span.finish(finish)
        rescue StandardError => e
          Datadog::Tracer.log.error(e.message)
        end
      end
    end
  end
end

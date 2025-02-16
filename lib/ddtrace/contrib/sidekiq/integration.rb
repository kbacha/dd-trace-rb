# typed: false
require 'ddtrace/contrib/integration'
require 'ddtrace/contrib/sidekiq/configuration/settings'
require 'ddtrace/contrib/sidekiq/patcher'

module Datadog
  module Contrib
    module Sidekiq
      # Description of Sidekiq integration
      class Integration
        include Contrib::Integration

        MINIMUM_VERSION = Gem::Version.new('3.5.4')
        MINIMUM_SERVER_INTERNAL_TRACING_VERSION = Gem::Version.new('5.2.4')

        register_as :sidekiq

        def self.version
          Gem.loaded_specs['sidekiq'] && Gem.loaded_specs['sidekiq'].version
        end

        def self.loaded?
          !defined?(::Sidekiq).nil?
        end

        def self.compatible?
          super && version >= MINIMUM_VERSION
        end

        # Only patch server internals on v5.2.4+ because that's when loading of
        # `Sidekiq::Launcher` stabilized. Sidekiq 4+ technically can support our
        # patches (with minor adjustments), but in order to avoid explicitly
        # requiring `sidekiq/launcher` ourselves (which could affect gem
        # initialization order), we are limiting this tracing to v5.2.4+.
        def self.compatible_with_server_internal_tracing?
          version >= MINIMUM_SERVER_INTERNAL_TRACING_VERSION
        end

        def default_configuration
          Configuration::Settings.new
        end

        def patcher
          Patcher
        end
      end
    end
  end
end

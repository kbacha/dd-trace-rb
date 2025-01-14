# typed: true
require 'ddtrace/span'
require 'ddtrace/opentelemetry/span'

module Datadog
  module OpenTelemetry
    # Defines extensions to ddtrace for OpenTelemetry support
    module Extensions
      def self.extended(base)
        Datadog::Span.prepend(OpenTelemetry::Span)
      end
    end
  end
end

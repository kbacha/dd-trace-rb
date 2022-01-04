require 'datadog/demo_env'
require 'ddtrace'

Datadog.configure do |c|
  c.service = 'acme-rack'
  c.diagnostics.debug = true if Datadog::DemoEnv.feature?('debug')
  c.analytics.enabled = true if Datadog::DemoEnv.feature?('analytics')
  c.runtime_metrics.enabled = true if Datadog::DemoEnv.feature?('runtime_metrics')

  c.use :rack if Datadog::DemoEnv.feature?('tracing')

  if Datadog::DemoEnv.feature?('pprof_to_file')
    # Reconfigure transport to write pprof to file
    c.profiling.exporter.transport = Datadog::DemoEnv.profiler_file_transport
  end
end

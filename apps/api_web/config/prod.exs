use Mix.Config

# For production, we configure the host to read the PORT
# from the system environment. Therefore, you will need
# to set PORT=80 before running your server.
#
# You should also configure the url host to something
# meaningful, we use this information when generating URLs.
#
# Finally, we also include the path to a manifest
# containing the digested version of static files. This
# manifest is generated by the mix phoenix.digest task
# which you typically run after static files are built.
config :api_web, ApiWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [scheme: "https", host: {:system, "HOST"}, port: 443],
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"

# configured separately so that we can have the health check not require
# SSL
config :site, :secure_pipeline,
  force_ssl: [
    host: nil,
    rewrite_on: [:x_forwarded_proto]
  ]

# by default, don't enable the event-stream type
config :api_web, :api_pipeline,
  authenticated_accepts: ["event-stream"],
  accepts: ["json", "json-api"]

config :api_web, :rate_limiter, limiter: ApiWeb.RateLimiter.Memcache

config :api_web, RateLimiter.Memcache,
  connection_opts: [
    namespace: "${HOST}",
    hostname: "${MEMCACHED_HOST}"
  ]

# Configures Elixir's Logger
config :sasl, errlog_type: :error

config :logger,
  handle_sasl_reports: true,
  level: :info,
  backends: [:console]

config :logger, :console,
  format: "$dateT$time [$level]$levelpad node=$node $metadata$message\n",
  metadata: [:request_id, :api_key, :records]

config :ehmon, :report_mf, {:ehmon, :info_report}

config :api_web, :rate_limiter,
  clear_interval: 60_000,
  max_anon_per_interval: 20,
  max_registered_per_interval: 1_000

threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
threads threads_count, threads_count
port ENV.fetch("PORT", 4567)
environment ENV.fetch("RACK_ENV", "development")
workers Integer(ENV.fetch("WEB_CONCURRENCY", 0))
preload_app!

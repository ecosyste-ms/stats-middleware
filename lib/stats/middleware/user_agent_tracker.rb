# frozen_string_literal: true

require 'logger'

module Stats
  module Middleware
    class UserAgentTracker
      def initialize(app, options = {})
        @app = app
        @redis = options[:redis] || (defined?(REDIS) && REDIS) || nil
        @path_filter = options[:path_filter] || ->(path) { path&.start_with?('/api/') }
        @logger = options[:logger] || (defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : Logger.new(STDOUT))
        @expiry_days = options[:expiry_days] || 31
        @redis_key_prefix = options[:redis_key_prefix] || 'api_requests'
      end

      def call(env)
        track_request(env) if should_track?(env)
        @app.call(env)
      end

      private

      def should_track?(env)
        @path_filter.call(env['PATH_INFO'])
      end

      def track_request(env)
        return unless @redis

        user_agent = env['HTTP_USER_AGENT'] || 'Unknown'
        today = Date.today.to_s
        
        # Use a sorted set for each day with user agents as members and counts as scores
        day_key = "#{@redis_key_prefix}:#{today}"
        
        # Increment the count for this user agent
        @redis.zincrby(day_key, 1, user_agent)
        
        # Set expiration to configured days (convert to seconds)
        @redis.expire(day_key, @expiry_days * 24 * 60 * 60)
      rescue => e
        @logger&.error "Stats::Middleware::UserAgentTracker error: #{e.message}"
      end
    end
  end
end
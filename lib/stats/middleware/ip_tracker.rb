# frozen_string_literal: true

require 'logger'

module Stats
  module Middleware
    class IpTracker
      def initialize(app, options = {})
        @app = app
        @redis = options[:redis] || (defined?(REDIS) && REDIS) || nil
        @path_filter = options[:path_filter] || ->(path) { path&.start_with?('/api/') }
        @logger = options[:logger] || (defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : Logger.new(STDOUT))
        @expiry_days = options[:expiry_days] || 31
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

        ip_address = get_client_ip(env)
        today = Date.today.to_s
        
        # Use a sorted set for each day with IP addresses as members and counts as scores
        day_key = "api_requests:ips:#{today}"
        
        # Increment the count for this IP address
        @redis.zincrby(day_key, 1, ip_address)
        
        # Set expiration to configured days (convert to seconds)
        @redis.expire(day_key, @expiry_days * 24 * 60 * 60)
      rescue => e
        @logger&.error "Stats::Middleware::IpTracker error: #{e.message}"
      end

      def get_client_ip(env)
        # Check for Cloudflare's original IP header first
        cf_connecting_ip = env['HTTP_CF_CONNECTING_IP']
        return cf_connecting_ip.strip if cf_connecting_ip && !cf_connecting_ip.empty?
        
        # Check for forwarded IPs (when behind proxy/load balancer)
        forwarded_for = env['HTTP_X_FORWARDED_FOR']
        if forwarded_for && !forwarded_for.empty?
          # Take the first IP if there are multiple (client -> proxy1 -> proxy2)
          forwarded_for.split(',').first.strip
        else
          # Direct connection
          env['REMOTE_ADDR'] || 'Unknown'
        end
      end
    end
  end
end
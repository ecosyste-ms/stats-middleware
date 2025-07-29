# frozen_string_literal: true

require "test_helper"

class Stats::TestIpTracker < Minitest::Test
  def setup
    @app = ->(env) { [200, {}, ['OK']] }
    @redis = Minitest::Mock.new
    @middleware = Stats::Middleware::IpTracker.new(@app, redis: @redis)
  end

  def test_tracks_ip_for_api_requests
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:ips:#{Date.today}", 1, '192.168.1.100'])
    @redis.expect(:expire, nil, ["api_requests:ips:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env)
    @redis.verify
  end

  def test_tracks_ip_from_x_forwarded_for_header_when_present
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_X_FORWARDED_FOR' => '10.0.0.1, 192.168.1.1',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:ips:#{Date.today}", 1, '10.0.0.1'])
    @redis.expect(:expire, nil, ["api_requests:ips:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env)
    @redis.verify
  end

  def test_tracks_ip_from_cloudflare_header_when_present
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_CF_CONNECTING_IP' => '203.0.113.1',
      'HTTP_X_FORWARDED_FOR' => '10.0.0.1, 192.168.1.1',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:ips:#{Date.today}", 1, '203.0.113.1'])
    @redis.expect(:expire, nil, ["api_requests:ips:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env)
    @redis.verify
  end

  def test_does_not_track_non_api_requests
    env = {
      'PATH_INFO' => '/advisories',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @middleware.call(env)
  end

  def test_handles_missing_ip_address_gracefully
    env = {
      'PATH_INFO' => '/api/v1/advisories'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:ips:#{Date.today}", 1, 'Unknown'])
    @redis.expect(:expire, nil, ["api_requests:ips:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env)
    @redis.verify
  end

  def test_handles_redis_errors_without_failing_the_request
    # Use a mock logger to suppress expected error output
    mock_logger = Minitest::Mock.new
    mock_logger.expect(:error, nil, [String])
    
    middleware = Stats::Middleware::IpTracker.new(@app, redis: @redis, logger: mock_logger)
    
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @redis.expect(:zincrby, proc { raise Redis::ConnectionError }, ["api_requests:ips:#{Date.today}", 1, '192.168.1.100'])
    
    response = middleware.call(env)
    assert_equal [200, {}, ['OK']], response
    
    @redis.verify
    mock_logger.verify
  end

  def test_uses_custom_path_filter
    custom_filter = ->(path) { path&.start_with?('/custom/') }
    middleware = Stats::Middleware::IpTracker.new(@app, redis: @redis, path_filter: custom_filter)
    
    env = {
      'PATH_INFO' => '/custom/endpoint',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:ips:#{Date.today}", 1, '192.168.1.100'])
    @redis.expect(:expire, nil, ["api_requests:ips:#{Date.today}", 31.days.to_i])
    
    middleware.call(env)
    @redis.verify
  end

  def test_uses_custom_expiry_days
    middleware = Stats::Middleware::IpTracker.new(@app, redis: @redis, expiry_days: 7)
    
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'REMOTE_ADDR' => '192.168.1.100'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:ips:#{Date.today}", 1, '192.168.1.100'])
    @redis.expect(:expire, nil, ["api_requests:ips:#{Date.today}", 7.days.to_i])
    
    middleware.call(env)
    @redis.verify
  end
end
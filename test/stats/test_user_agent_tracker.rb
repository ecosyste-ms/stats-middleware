# frozen_string_literal: true

require "test_helper"

class Stats::TestUserAgentTracker < Minitest::Test
  def setup
    @app = ->(env) { [200, {}, ['OK']] }
    @redis = Minitest::Mock.new
    @middleware = Stats::Middleware::UserAgentTracker.new(@app, redis: @redis)
  end

  def test_tracks_user_agent_for_api_requests
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:#{Date.today}", 1, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'])
    @redis.expect(:expire, nil, ["api_requests:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env)
    @redis.verify
  end

  def test_tracks_unknown_user_agent_when_header_is_missing
    env = {
      'PATH_INFO' => '/api/v1/advisories'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:#{Date.today}", 1, 'Unknown'])
    @redis.expect(:expire, nil, ["api_requests:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env)
    @redis.verify
  end

  def test_does_not_track_non_api_requests
    env = {
      'PATH_INFO' => '/advisories',
      'HTTP_USER_AGENT' => 'Mozilla/5.0'
    }
    
    @middleware.call(env)
  end

  def test_handles_nil_path_info_gracefully
    env = {
      'HTTP_USER_AGENT' => 'Mozilla/5.0'
    }
    
    @middleware.call(env)
  end

  def test_handles_redis_errors_without_failing_the_request
    # Use a mock logger to suppress expected error output
    mock_logger = Minitest::Mock.new
    mock_logger.expect(:error, nil, [String])
    
    middleware = Stats::Middleware::UserAgentTracker.new(@app, redis: @redis, logger: mock_logger)
    
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_USER_AGENT' => 'TestAgent/1.0'
    }
    
    @redis.expect(:zincrby, proc { raise Redis::ConnectionError }, ["api_requests:#{Date.today}", 1, 'TestAgent/1.0'])
    
    response = middleware.call(env)
    assert_equal [200, {}, ['OK']], response
    
    @redis.verify
    mock_logger.verify
  end

  def test_tracks_different_user_agents_separately
    env1 = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_USER_AGENT' => 'curl/7.84.0'
    }
    
    env2 = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_USER_AGENT' => 'PostmanRuntime/7.29.2'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:#{Date.today}", 1, 'curl/7.84.0'])
    @redis.expect(:expire, nil, ["api_requests:#{Date.today}", 31.days.to_i])
    @redis.expect(:zincrby, nil, ["api_requests:#{Date.today}", 1, 'PostmanRuntime/7.29.2'])
    @redis.expect(:expire, nil, ["api_requests:#{Date.today}", 31.days.to_i])
    
    @middleware.call(env1)
    @middleware.call(env2)
    @redis.verify
  end

  def test_uses_custom_path_filter
    custom_filter = ->(path) { path&.start_with?('/custom/') }
    middleware = Stats::Middleware::UserAgentTracker.new(@app, redis: @redis, path_filter: custom_filter)
    
    env = {
      'PATH_INFO' => '/custom/endpoint',
      'HTTP_USER_AGENT' => 'TestAgent/1.0'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:#{Date.today}", 1, 'TestAgent/1.0'])
    @redis.expect(:expire, nil, ["api_requests:#{Date.today}", 31.days.to_i])
    
    middleware.call(env)
    @redis.verify
  end

  def test_uses_custom_redis_key_prefix
    middleware = Stats::Middleware::UserAgentTracker.new(@app, redis: @redis, redis_key_prefix: 'custom_stats')
    
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_USER_AGENT' => 'TestAgent/1.0'
    }
    
    @redis.expect(:zincrby, nil, ["custom_stats:#{Date.today}", 1, 'TestAgent/1.0'])
    @redis.expect(:expire, nil, ["custom_stats:#{Date.today}", 31.days.to_i])
    
    middleware.call(env)
    @redis.verify
  end

  def test_uses_custom_expiry_days
    middleware = Stats::Middleware::UserAgentTracker.new(@app, redis: @redis, expiry_days: 7)
    
    env = {
      'PATH_INFO' => '/api/v1/advisories',
      'HTTP_USER_AGENT' => 'TestAgent/1.0'
    }
    
    @redis.expect(:zincrby, nil, ["api_requests:#{Date.today}", 1, 'TestAgent/1.0'])
    @redis.expect(:expire, nil, ["api_requests:#{Date.today}", 7.days.to_i])
    
    middleware.call(env)
    @redis.verify
  end
end